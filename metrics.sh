#!/usr/bin/env bash
# =============================================================================
# metrics.sh — claude-sdd-harness session cost meter
#
# Origin: inspired by / forked from Bettatech.
# Adapted for macOS / POSIX shell by Rubén Juárez Pérez.
#
# Two modes:
#   1. Hook mode (default): reads the SessionEnd hook JSON on stdin, parses the
#      session transcript, and appends one row to progress/metrics.jsonl with
#      tokens (deduped by message id, cache writes split by 5m/1h TTL), a
#      per-model breakdown, turns, and latency.
#   2. Report mode (`./metrics.sh --report`): aggregates progress/metrics.jsonl
#      by feature so you can see the real token *and dollar* cost of each feature.
#
# Never blocks the session: hook mode always exits 0.
# Requires: jq.
# =============================================================================
set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
METRICS_FILE="$ROOT/progress/metrics.jsonl"

# --- Pricing (USD per 1,000,000 tokens) --------------------------------------
# Edit this table to match the models you run and current list prices.
#   in  = input            out = output           r  = cache read  (0.1x input)
#   w5  = cache write 5m TTL (1.25x input)        w1 = cache write 1h TTL (2x input)
# Models absent from this table are reported with cost 0 and flagged as UNPRICED.
PRICES_JSON='{
  "claude-opus-4-8":   { "in": 5,  "out": 25, "r": 0.5,  "w5": 6.25, "w1": 10 },
  "claude-opus-4-7":   { "in": 5,  "out": 25, "r": 0.5,  "w5": 6.25, "w1": 10 },
  "claude-opus-4-6":   { "in": 5,  "out": 25, "r": 0.5,  "w5": 6.25, "w1": 10 },
  "claude-sonnet-4-6": { "in": 3,  "out": 15, "r": 0.3,  "w5": 3.75, "w1": 6  },
  "claude-haiku-4-5":  { "in": 1,  "out": 5,  "r": 0.1,  "w5": 1.25, "w1": 2  }
}'

# --- Report mode -------------------------------------------------------------
if [ "${1:-}" = "--report" ]; then
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq not found — cannot build report" >&2; exit 1
  fi
  if [ ! -s "$METRICS_FILE" ]; then
    echo "No metrics yet ($METRICS_FILE is empty or missing)."; exit 0
  fi

  # Warn about any model that appears in the data but has no price entry.
  UNPRICED="$(jq -s -r --argjson p "$PRICES_JSON" '
      [ .[] | (.by_model // {}) | keys[] ] | unique
      | map(select($p[.] == null)) | join(", ")
    ' "$METRICS_FILE" 2>/dev/null)"

  echo "== cost per feature (from $(basename "$METRICS_FILE")) =="
  {
    printf 'feature\tsessions\tturns\tinput\toutput\tcache_read\tcache_creation\tduration_s\tcost_usd\n'
    jq -s -r --argjson p "$PRICES_JSON" '
      # Dollar cost of one session row, summed across its per-model usage.
      def row_cost($bym):
        ( ($bym // {}) | to_entries | map(
            .value as $u | ($p[.key]) as $pm |
            if $pm == null then 0
            else ($u.input          // 0) * $pm.in
               + ($u.output         // 0) * $pm.out
               + ($u.cache_read     // 0) * $pm.r
               + ($u.cache_creation_5m // 0) * $pm.w5
               + ($u.cache_creation_1h // 0) * $pm.w1
            end
          ) | add // 0
        ) / 1000000;

      group_by(.feature_id // "none")
      | .[]
      | [
          (.[0].feature_id // "none"),
          length,
          (map(.turns // 0) | add),
          (map(.tokens.input // 0) | add),
          (map(.tokens.output // 0) | add),
          (map(.tokens.cache_read // 0) | add),
          (map(.tokens.cache_creation // 0) | add),
          (map(.duration_seconds // 0) | add | floor),
          (map(row_cost(.by_model)) | add | . * 100 | round / 100)
        ]
      | @tsv
    ' "$METRICS_FILE"
  } | column -t -s "$(printf '\t')"

  [ -n "$UNPRICED" ] && echo "note: unpriced models (counted as \$0): $UNPRICED"
  exit 0
fi

# --- Hook mode ---------------------------------------------------------------
# Reads the SessionEnd hook payload from stdin. Best-effort: any failure is
# swallowed so the session is never blocked.
command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat)"
TRANSCRIPT="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)"
SESSION="$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)"

[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0

# Active feature context (so cost can be attributed to a feature).
FEATURE="none"
FSTATUS="idle"
if [ -f "$ROOT/progress/active.json" ]; then
  FEATURE="$(jq -r '.feature_id // "none"' "$ROOT/progress/active.json" 2>/dev/null || echo none)"
  FSTATUS="$(jq -r '.status // "idle"' "$ROOT/progress/active.json" 2>/dev/null || echo idle)"
fi
[ -z "$FEATURE" ] && FEATURE="none"

LINE="$(jq -s -c \
  --arg session "$SESSION" \
  --arg feature "$FEATURE" \
  --arg status "$FSTATUS" \
  --arg logged_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
  def epoch: sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601;

  # Token sums for a set of assistant rows (the same shape is reused per model).
  def usage_of($rows):
    {
      input:             ($rows | map(.message.usage.input_tokens // 0) | add // 0),
      output:            ($rows | map(.message.usage.output_tokens // 0) | add // 0),
      cache_read:        ($rows | map(.message.usage.cache_read_input_tokens // 0) | add // 0),
      cache_creation:    ($rows | map(.message.usage.cache_creation_input_tokens // 0) | add // 0),
      cache_creation_5m: ($rows | map(.message.usage.cache_creation.ephemeral_5m_input_tokens // 0) | add // 0),
      cache_creation_1h: ($rows | map(.message.usage.cache_creation.ephemeral_1h_input_tokens // 0) | add // 0)
    };

  # All timestamps, converted defensively to epoch seconds.
  ([ .[] | .timestamp // empty | select(. != "") | (try epoch catch empty) ]) as $epochs

  # Assistant turns, deduped by message.id (multi-block turns repeat the same usage).
  | (reduce (.[] | select(.type == "assistant")) as $m
        ({seen: {}, rows: []};
         if .seen[$m.message.id] then .
         else .seen[$m.message.id] = true | .rows += [$m] end)
    ).rows as $rows

  | {
      logged_at: $logged_at,
      session_id: $session,
      feature_id: $feature,
      status: $status,
      duration_seconds: (if ($epochs | length) >= 2
                         then (($epochs | max) - ($epochs | min)) else 0 end),
      turns: ($rows | length),
      tokens: usage_of($rows),
      by_model: ($rows
        | group_by(.message.model // "unknown")
        | map({ (.[0].message.model // "unknown"): ({ turns: length } + usage_of(.)) })
        | add)
    }
' "$TRANSCRIPT" 2>/dev/null)"

[ -n "$LINE" ] && printf '%s\n' "$LINE" >> "$METRICS_FILE"
exit 0
