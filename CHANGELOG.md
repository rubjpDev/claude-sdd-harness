# Changelog

All notable changes to this harness. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions are the
repository tags (`V_1.0`, `V_2.0`, …).

## [Unreleased] — v3-extended

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
