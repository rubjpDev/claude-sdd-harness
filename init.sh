#!/usr/bin/env bash
# =============================================================================
# init.sh — claude-sdd-harness verification gate
#
# Origin: inspired by / forked from Bettatech.
# Adapted for macOS / POSIX shell by Rubén Juárez Pérez.
#
# Behavior:
#   - In the empty bootstrap state (no source code yet) it PASSES with WARNs.
#   - It only enforces quality gates once source code exists in the target repos.
#   - Exits non-zero on any FAIL.
#
# Source-code detection: looks for .py files in the paths declared in repos.json.
# Falls back to any .py file under the harness root if repos.json isn't readable.
# =============================================================================
set -u

FAIL=0
ok()   { printf '[OK]   %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1"; FAIL=1; }

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "[FAIL] cannot cd to harness root"; exit 1; }

echo "== claude-sdd-harness gate =="

# --- 1. Python >= 3.12 -------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
  PYV="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
  if python3 -c 'import sys; sys.exit(0 if sys.version_info[:2] >= (3, 12) else 1)'; then
    ok "python3 ${PYV} (>= 3.12)"
  else
    fail "python3 ${PYV} is older than 3.12"
  fi
else
  fail "python3 not found"
fi

# --- 2. Poetry (WARN until code exists) --------------------------------------
if command -v poetry >/dev/null 2>&1; then
  ok "poetry present ($(poetry --version 2>/dev/null))"
  HAVE_POETRY=1
else
  warn "poetry not installed — quality gates will be skipped until it is"
  HAVE_POETRY=0
fi

# --- 3. Base harness files exist --------------------------------------------
for f in \
  AGENTS.md \
  feature_list.json \
  progress/current.md \
  docs/architecture.md \
  docs/conventions.md \
  docs/verification.md \
  CHECKPOINTS.md
do
  if [ -f "$f" ]; then ok "exists: $f"; else fail "missing: $f"; fi
done

# --- 4. Validate feature_list.json ------------------------------------------
if [ -f feature_list.json ]; then
  if jq empty feature_list.json >/dev/null 2>&1; then
    ok "feature_list.json parses"

    INPROG="$(jq '[.features[]? | select(.status == "in_progress")] | length' feature_list.json)"
    if [ "${INPROG:-0}" -le 1 ]; then
      ok "at most one feature in_progress (found ${INPROG:-0})"
    else
      fail "more than one feature in_progress (found ${INPROG})"
    fi

    # The vocabulary lives in feature_list.json (rules.valid_status) — one copy only.
    BADSTATUS="$(jq -r '(.rules.valid_status // ["pending","in_progress","done","blocked"]) as $valid | [.features[]? | select(.status as $s | ($valid | index($s)) | not) | .id] | join(", ")' feature_list.json)"
    if [ -z "$BADSTATUS" ]; then
      ok "all feature statuses valid"
    else
      fail "invalid status on features: ${BADSTATUS}"
    fi
  else
    fail "feature_list.json does not parse"
  fi
fi

# --- 4b. arch-map staleness (WARN only) --------------------------------------
# docs/arch-map.json is a generated view. It carries the commit it was built
# from, per repo; warn when HEAD has drifted well past it so it doesn't rot
# silently. Regenerate with the arch-map skill (/arch-map).
ARCH_MAP_MAX_COMMITS=20
if [ -f docs/arch-map.json ] && command -v jq >/dev/null 2>&1; then
  if ! jq empty docs/arch-map.json >/dev/null 2>&1; then
    fail "docs/arch-map.json does not parse"
  else
    while IFS="	" read -r rid sha; do
      [ -z "$rid" ] && continue
      rpath="$ROOT/$(jq -r --arg id "$rid" '.repos[]? | select(.id == $id) | .working_dir' repos.json 2>/dev/null)"
      [ -d "$rpath/.git" ] || continue
      if ! git -C "$rpath" cat-file -e "${sha}^{commit}" 2>/dev/null; then
        warn "arch-map: commit ${sha} unknown in ${rid} — map needs a full rebuild (/arch-map)"
        continue
      fi
      behind="$(git -C "$rpath" rev-list --count "${sha}..HEAD" 2>/dev/null || echo 0)"
      if [ "${behind:-0}" -gt "$ARCH_MAP_MAX_COMMITS" ]; then
        warn "arch-map: ${rid} is ${behind} commits past the mapped state — re-run /arch-map"
      else
        ok "arch-map: ${rid} current (${behind} commits behind HEAD)"
      fi
    done < <(jq -r '.generated_at_commit // {} | to_entries[] | "\(.key)\t\(.value)"' docs/arch-map.json 2>/dev/null)
  fi
fi

# --- 5. Detect source code in declared repo paths ----------------------------
# Read backend paths from repos.json; fall back to harness root.
PY_SOURCE_DIRS=""
if command -v jq >/dev/null 2>&1 && [ -f repos.json ]; then
  # Collect paths for repos that are likely Python (have a poetry-style verify)
  while IFS= read -r rpath; do
    [ -z "$rpath" ] && continue
    # rpath is relative to the harness root; resolve it
    resolved="$ROOT/$rpath"
    [ -d "$resolved" ] && PY_SOURCE_DIRS="$PY_SOURCE_DIRS $resolved"
  done < <(jq -r '.repos[]? | select(.default_verify[]? | test("poetry")) | .working_dir' repos.json 2>/dev/null)
fi
# Fallback: harness root itself
[ -z "$PY_SOURCE_DIRS" ] && PY_SOURCE_DIRS="$ROOT"

HAS_PY_CODE=0
for d in $PY_SOURCE_DIRS; do
  if find "$d" -maxdepth 4 -name "*.py" \
      ! -path "*/.git/*" ! -path "*/__pycache__/*" \
      ! -path "*/.venv/*" ! -path "*/venv/*" \
      -not -path "$ROOT/init.sh" \
      2>/dev/null | grep -q .; then
    HAS_PY_CODE=1
    break
  fi
done

HAS_TESTS=0
for d in $PY_SOURCE_DIRS; do
  if find "$d" -maxdepth 4 -name "test_*.py" -o -name "*_test.py" \
      ! -path "*/.git/*" ! -path "*/__pycache__/*" \
      ! -path "*/.venv/*" 2>/dev/null | grep -q .; then
    HAS_TESTS=1
    break
  fi
done

# --- 6. Quality gates (only when code exists) --------------------------------
if [ "$HAS_PY_CODE" -eq 0 ]; then
  warn "bootstrap state: no Python source code found — skipping ruff/mypy/pytest"
elif [ "$HAVE_POETRY" -eq 0 ]; then
  warn "code present but poetry missing — install poetry to run quality gates"
else
  # Run gates from the primary backend working dir if present, else harness root
  GATE_DIR="$ROOT"
  if command -v jq >/dev/null 2>&1 && [ -f repos.json ]; then
    PRIMARY="$(jq -r '.repos[]? | select(.role == "main-service") | .working_dir' repos.json 2>/dev/null | head -1)"
    [ -n "$PRIMARY" ] && [ -d "$ROOT/$PRIMARY" ] && GATE_DIR="$ROOT/$PRIMARY"
  fi

  cd "$GATE_DIR" || { fail "cannot cd to $GATE_DIR"; cd "$ROOT"; }

  if poetry run ruff check . >/tmp/harness_ruff.log 2>&1; then
    ok "ruff check clean"
  else
    fail "ruff check found issues (see /tmp/harness_ruff.log)"; tail -10 /tmp/harness_ruff.log
  fi

  # mypy — only if an app/src dir exists in the gate dir
  MYPY_TARGET=""
  for d in app src; do
    [ -d "$d" ] && { MYPY_TARGET="$d"; break; }
  done
  if [ -n "$MYPY_TARGET" ]; then
    if poetry run mypy "$MYPY_TARGET" >/tmp/harness_mypy.log 2>&1; then
      ok "mypy clean"
    else
      fail "mypy found issues (see /tmp/harness_mypy.log)"; tail -10 /tmp/harness_mypy.log
    fi
  else
    warn "no app/ or src/ dir found — skipping mypy"
  fi

  if [ "$HAS_TESTS" -eq 1 ]; then
    if poetry run pytest -q >/tmp/harness_pytest.log 2>&1; then
      ok "pytest green"
    else
      fail "pytest failed (see /tmp/harness_pytest.log)"; tail -15 /tmp/harness_pytest.log
    fi
  else
    warn "no tests found — skipping pytest"
  fi

  cd "$ROOT"
fi

# --- 7. Verdict --------------------------------------------------------------
echo "== gate result =="
if [ "$FAIL" -ne 0 ]; then
  echo "[FAIL] verification gate failed"
  exit 1
fi
echo "[OK] verification gate passed"
exit 0
