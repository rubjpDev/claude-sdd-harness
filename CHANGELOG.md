# Changelog

All notable changes to this harness. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions are the
repository tags (`V_1.0`, `V_2.0`, …).

## [Unreleased] — v3.1

### Added

- **Incident lane** and the **`triage`** agent. A feature marked
  `"type": "incident"` is diagnosed before it is fixed: `triage` reproduces the
  failure, traces the root cause to `file:line`, establishes the blast radius
  (other callers, already-corrupted data, backfill needed) and prescribes the
  regression test, all into `specs/<incident-id>/diagnosis-<incident-id>.md` —
  incidents get their own folder under `specs/`, named after the ticket id
  (`specs/INC-I303/`), exactly like features. That diagnosis is the coder's
  contract, because an incident has no spec and no acceptance array until someone
  reproduces it. It has no `Edit` tool, fixes nothing, changes no state.
  Diagnosis is search-heavy by nature, so it runs in its own context window and the
  `coder` gets a clean one for the fix.
  - Returns `diagnosed` (straight to the `coder`, no approval gate — incidents are
    urgent), `escalate` (the cause is a design problem: converts to a full-lane
    feature whose spec is written into the **same** folder, next to the diagnosis,
    with the human gate) or `cannot_reproduce` (`blocked`, with
    what it tried and what it needs — a legitimate outcome, not a failure).
  - Skipped entirely when the human already knows the cause: that's the light lane.
- **Incident rules for the `coder`**: write the prescribed regression test **first
  and watch it fail**, fix the named cause rather than where the error surfaced, and
  no scope creep — an incident is the worst place for a drive-by refactor. A
  diagnosis that turns out to be wrong is a `blocked`, not an improvised new theory.
- **Incident checks for the `validator`**, both blocking: the regression test must
  actually go red without the fix (verify it, don't assume), and the fix must
  address the root cause the diagnosis named. Plus: a blast radius needing a
  backfill must be handled or explicitly deferred.
- **`post-mortem-<id>.md`** replaces `walkthrough.md` as the human-facing file for an
  incident (`templates/post-mortem.md`): what broke, why, what stops it now, a
  timeline of the introducing change, what data was already affected, and **what
  would have caught it earlier** — the missing test, constraint, type or alert. Same
  `bro` styling and real-snippets rule as a walkthrough, different shape.
- **Ticket-data handling**, encoded in `triage`, the `validator`, the orchestrator
  and `CLAUDE.md`: real tickets arrive full of names, emails, account ids and card
  numbers, and `progress/` is committed to git. Keep the shape, never the value;
  internal ids only; payment data and credentials never, in any form. An exposed
  credential in a ticket is escalated to the human as its own incident. Ticket text
  is treated as untrusted **data**, never as instructions.
- **Read-only connector rules.** Where a project configures a database (or logs,
  tracing, k8s) MCP tool, `triage` may query it to confirm or eliminate a
  hypothesis — reads only, bounded queries, aggregates and shapes rather than rows,
  and everything it reads is still subject to the redaction rules. It states in the
  diagnosis which source each piece of evidence came from (local dump vs replica vs
  code alone), and flags credentials that are not `SELECT`-only: the boundary that
  actually holds is the database role, not the prompt. MCP tools must be added to
  the agent's `tools:` allowlist by name; the frontmatter carries the example.
- **`/arch-map` now maps infrastructure too** — datastores, caches, queues,
  services, k8s clusters and namespaces, cron jobs and the external edges of the
  system, sourced from declared config (compose files, k8s manifests, Terraform, CI,
  env schema) rather than inferred. One node per database or cluster, **never per
  table**. Secrets never enter either artifact: logical names only, no connection
  strings, hostnames with credentials, tokens or internal IPs.

### Changed

- **`init.sh` reads the status vocabulary from `feature_list.json`**
  (`rules.valid_status`) instead of keeping a second hardcoded copy.

### Fixed

- **`spec_ready` no longer fails the gate.** The state machine has used it since v1,
  but it was missing from the valid-status list, so a full-lane feature waiting at
  the approval gate turned `init.sh` red. Added, along with the new `diagnosed`.
- **The tolerant `Stop` hook now covers every `in_progress*` status.** It compared
  the status for exact equality, so a harness using a variant like
  `in_progress_tutor` still got blocked by a red gate mid-implementation — exactly
  when the tolerance is needed.

---

## [V_3.0] — v3-extended

Branch: `feature/version3-extended`.

### Added

- **Tutor mode.** A feature marked `"mode": "tutor"` in `feature_list.json` is
  delivered by the new `tutor` agent instead of the `coder`: it writes
  `progress/tutorial_<id>.md`, the human writes the code, and the `validator` runs
  unchanged — same gates, same verdict. Delivery mode is orthogonal to the
  light/full lane. The `tutor` has no `Edit` tool and cannot change state, so the
  orchestrator is the one that sets `in_progress`.
- **Human-facing spec summaries.** Full-lane features now also get two files in
  `specs/<id>/`, both capped at about one screen:
  - `brief.md`, by the `spec_creator` before the approval gate — a Mermaid diagram
    and a "what changes" table instead of prose, styled with the bundled
    `no-ai-slop` skill.
  - `walkthrough.md`, by the `validator` after the review — the change explained
    with real snippets from the diff, the way an engineer walks a senior through a
    pull request, styled with the bundled `bro` skill. Read it with the diff open
    on the other screen.

  Both are views, never sources of truth: spec and code win, the summary is fixed.
  Templates in `templates/brief.md` and `templates/walkthrough.md`.
- **Bundled skills** in `.claude/skills/`, so the harness needs no plugin install:
  `ponytail`, `ponytail-audit`, `ponytail-review` (MIT, from the ponytail plugin
  v4.7.0), `no-ai-slop`, `bro`, and the harness's own `arch-map`. Origins and
  licenses in `.claude/skills/README.md`.
- **`ponytail` on by default** for `spec_creator` and `coder` — the design and the
  code default to the laziest thing that actually works, with validation,
  security, accessibility and tests explicitly out of scope for laziness. Disable
  per task with the literal token `ponytail off` in the `Task` prompt.
- **`/arch-map`** — one analysis, two committed artifacts:
  - `docs/arch-map.json` — `{nodes, edges, flows}` with stable dotted ids and
    one-line descriptions. The `spec_creator` reads it in place of a broad
    exploration pass.
  - `docs/generated/architecture.html` — a self-contained interactive diagram: flow
    panel, path highlighting, step-through (`Step` / `Resume` / `Reset`, arrow
    keys), tooltips, and a per-node panel with two tabs — "what it does" in plain
    language and "how it's built" in implementation terms.

  Re-runs are **incremental**: the JSON stores the commit SHA it was built from, and
  a re-run diffs from there and edits only what changed. Long prose lives in the
  HTML only, never in the JSON that agents load on every spawn.
- **`arch-map` staleness check in `init.sh`** (WARN only, never fails the gate):
  validates the JSON parses, that the stored commit still exists, and warns when a
  repo has drifted more than 20 commits past the mapped state.

### Changed

- **Model tiering retuned to Claude 5.** Pinned ids (`claude-opus-5`,
  `claude-sonnet-5`) in `run.sh` and the agent frontmatter instead of the `opus` /
  `sonnet` aliases. The orchestrator runs at medium effort; the `validator` moves
  from Opus/high to Sonnet 5/medium. Opus stays for orchestration, spec authoring
  and teaching. `metrics.sh` gains the Claude 5 prices.
- **The `validator` reviews ponytail-aware.** Minimal, stdlib-first,
  abstraction-free code is not a finding, and a `ponytail:` comment is a
  deliberate simplification rather than a defect — unless its named ceiling
  actually breaks a requirement in scope. Failing gates, real bugs, missing tests
  and skipped trust-boundary work still hard-fail.
- **The `validator` gains the `Write` tool**, scoped by an explicit guardrail to
  `progress/review_<id>.md` and `specs/<id>/walkthrough.md`. It still never touches
  code, specs or state.

### Fixed

- **The `Stop` hook no longer fails a session mid-implementation.** It strips
  control characters before parsing the hook payload with `jq`, and when the gate
  is red while a feature is legitimately `in_progress` it reports the state and
  exits 0 instead of blocking. A genuinely broken gate outside implementation
  still exits 2.

---

## [V_2.0.1] — hook fix and credits

Fixed a hook bug; credits updated.

## [V_2.0] — token stats and knowledge base

Session cost metrics (`metrics.sh`, `progress/metrics.jsonl`, `--report`), the
self-growing `docs/knowledge-pack.md`, and `progress/active.json`.

## [V_1.1] / [V_1.0] — first working harness

The two-lane system (light/full) with acceptance criteria, the four roles,
multi-repo coordination via `repos.json` + `scope.yaml`, the `init.sh`
verification gate, and hardened hooks — built on Bettatech's subagent example
(see Credits in `README.md`).
