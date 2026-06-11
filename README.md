# claude-sdd-harness — A Spec-Driven Agentic Harness for Claude Code

> A small, opinionated orchestration layer that turns Claude Code into a
> disciplined, multi-role software pipeline: **spec → human approval →
> implementation → review**, with state on disk instead of in the chat.
>
> Runtime: macOS / Linux, POSIX shell. Tooling: Claude Code (subagents + hooks).
> Origin: inspired by / forked from **Bettatech**. Ported, renamed, and
> extended by Rubén Juárez Pérez.

---

## Table of Contents

- [What this is (and what it is not)](#what-this-is-and-what-it-is-not)
- [Why it exists — the three problems it solves](#why-it-exists--the-three-problems-it-solves)
- [Repository layout](#repository-layout)
- [Prerequisites](#prerequisites)
- [Install / wire it to your repos](#install--wire-it-to-your-repos)
- [The four roles](#the-four-roles)
- [The two-lane system](#the-two-lane-system)
- [The lifecycle / state machine](#the-lifecycle--state-machine)
- [Running it with Claude Code](#running-it-with-claude-code)
- [A worked example, end to end](#a-worked-example-end-to-end)
- [The verification gate (`init.sh`) and hooks](#the-verification-gate-initsh-and-hooks)
- [File-by-file reference](#file-by-file-reference)
- [Troubleshooting](#troubleshooting)
- [Extending it (v2, v3, …)](#extending-it-v2-v3-)
- [Credits](#credits)

---

## What this is (and what it is not)

`claude-sdd-harness` is a **coordination layer that lives in its own directory**,
sitting beside the repositories it builds. You launch Claude Code from inside
the harness directory; the main session takes on a single role — the
**orchestrator** — and delegates real work to specialized subagents.

It **is**:
- A way to keep Claude Code's context window clean on long, multi-feature work.
- A spec-first discipline: substantial features are designed and human-approved
  before a line of code is written.
- A reproducible pipeline whose state lives in files you can read, diff, and commit.

It is **not**:
- A framework you import. There is no runtime library — it's Markdown, JSON,
  one shell script, and Claude Code's native subagent/hook features.
- An autonomous agent. There is a deliberate **human approval gate**.
- Tied to any one stack. The default config targets a Python/FastAPI + React
  project, but `repos.json` and `docs/` make it portable.

---

## Why it exists — the three problems it solves

**1. Context rot.** A long Claude Code session accumulates file reads, tool
output, dead ends, and intermediate reasoning. Every token costs money on the
next turn and crowds out the file you actually need next. The harness pushes
detail into subagents that run in their own context windows and return only a
one-line reference.

**2. Broken telephone.** When one agent passes a long natural-language result
to another, detail degrades. Here, subagents **write their output to disk**
(`specs/<id>/`, `progress/impl_<id>.md`, `progress/review_<id>.md`) and return
only a pointer. The next role reads the file, not a paraphrase.

**3. Undisciplined "just code it".** Letting an LLM jump straight to code on a
non-trivial feature produces plausible-looking output that's subtly wrong. The
harness forces substantial features through a written spec (scope + EARS
requirements + design + tasks) and a human approval gate before implementation.

A note on cost: subagent-heavy workflows can use several times the tokens of a
single-thread session. The harness counters this with a **two-lane system** —
trivial work skips the heavy machinery entirely (see below).

---

## Repository layout

The harness is a **standalone repo**, a sibling of the repos it coordinates:

```
~/dev/
├── claude-sdd-harness/          ← this repo. You launch Claude Code from here.
│   ├── .claude/
│   │   ├── agents/
│   │   │   ├── orchestrator.md
│   │   │   ├── spec_creator.md
│   │   │   ├── coder.md
│   │   │   └── validator.md
│   │   └── settings.json   ← hooks + permissions
│   ├── CLAUDE.md           ← auto-loaded; pins the session to "orchestrator"
│   ├── AGENTS.md           ← navigation map / hard rules
│   ├── CHECKPOINTS.md      ← reusable review baseline
│   ├── repos.json          ← which repos this harness drives
│   ├── feature_list.json   ← the feature index (source of state)
│   ├── init.sh             ← the verification gate
│   ├── templates/          ← scope.yaml, requirements.md, design.md, tasks.md
│   ├── docs/               ← architecture, conventions, verification, knowledge-pack
│   ├── specs/              ← one folder per full-lane feature (the source of truth)
│   └── progress/           ← active.json, current.md, history.md, impl_*, review_*
├── example-backend/       ← a repo the harness builds (no harness files inside)
└── example-frontend/      ← another repo the harness builds
```

Key rule: **no harness artifacts ever go inside the repos being built.** The
backend and frontend stay clean; all orchestration lives here.

---

## Prerequisites

- **Claude Code** installed and authenticated.
- **bash/zsh** (macOS or Linux). The harness uses POSIX shell, not PowerShell.
- **jq** — used by `init.sh` and the Stop hook to parse JSON. (`brew install jq`)
- The target repos cloned as **siblings** of the harness directory.
- For the default Python config: **Python ≥ 3.12** and **Poetry** (only needed
  once the target repo has source code; `init.sh` degrades gracefully before that).

---

## Install / wire it to your repos

1. Clone this harness next to the repos it will drive:
   ```bash
   cd ~/dev
   git clone <your-harness-repo> claude-sdd-harness
   ```
2. Edit **`repos.json`** to declare your repos: their `working_dir` (relative to
   the harness root, e.g. `../example-backend`), stack, and `default_verify`
   commands. The `main-service` role marks the primary repo.
3. Fill in **`docs/`** with your project's reality:
   - `architecture.md` — what "good work" means here (layering, patterns).
   - `conventions.md` — style, naming, error handling, migration rules.
   - `verification.md` — how to prove a change works (commands, coverage target).
   - `knowledge-pack.md` — a living index that accelerates the `spec_creator`.
4. Make the gate executable and run it:
   ```bash
   chmod +x init.sh
   ./init.sh        # should pass with [WARN]s while the repos are empty
   ```

That's it. There is nothing to compile or install — the "engine" is Claude Code.

---

## The four roles

Each role is a Claude Code subagent defined in `.claude/agents/*.md` (YAML
frontmatter + system prompt). The orchestrator spawns the others with the
`Task` tool.

| Role | Spawned how | Writes code? | Closes features? | One-line return |
|---|---|---|---|---|
| **orchestrator** | the main session (pinned by `CLAUDE.md`) | ❌ | ❌ | — |
| **spec_creator** | `Task` → spec_creator | ❌ (writes specs only) | ❌ | `spec_ready -> specs/<id>/` |
| **coder** | `Task` → coder | ✅ | ❌ (hands back) | `done -> progress/impl_<id>.md` |
| **validator** | `Task` → validator | ❌ | ✅ (APPROVED closes) | `APPROVED -> progress/review_<id>.md` |

**orchestrator** — Reads state, picks the lane, delegates, holds the human
approval gate, updates `progress/`. Never edits source or tests. Never marks a
feature `done`. May answer pure read/exploration questions directly without
spawning anything.

**spec_creator** — For full-lane features only. Fills the four spec files in
`specs/<id>/`: `scope.yaml`, `requirements.md` (strict **EARS**, stable `R`
ids), `design.md`, `tasks.md` (stable `T` ids mapped to `R` ids). Does not
invent business rules — undefined points become open questions and a `blocked`
signal.

**coder** — Implements exactly one feature, end to end, with tests. Reads the
whole `specs/<id>/` (full lane) or the `acceptance` array (light lane). Every
code change ships with its test. Self-verifies via `./init.sh`. Writes a full
`progress/impl_<id>.md` (including a requirement→test map). Never marks the
feature `done` — it hands control back.

**validator** — Reviews the coder's work against `CHECKPOINTS.md`, the spec, and
the docs. Runs `./init.sh` (must be green). Produces `progress/review_<id>.md`
with a requirement-coverage table and a checkpoint walk. Emits **APPROVED** or
**CHANGES_REQUESTED**. Never edits code — it cites `file:line` and sends it back.

---

## The two-lane system

Not every change deserves a full spec. The orchestrator picks a lane:

| Complexity | Lane | Flow |
|---|---|---|
| Trivial — one file, obvious (add a field, a health route) | **Light** | `acceptance` criteria in `feature_list.json`, no `specs/` folder. orchestrator → coder → validator |
| Substantial — real design, cross-repo, external integrations, AI/auth/payments | **Full** | spec_creator writes `specs/<id>/` → **HUMAN APPROVAL** → coder → validator |

This is the main defense against the token cost (and ceremony) of over-using
subagents. Trivial work stays cheap; design-heavy work gets the rigor it needs.

---

## The lifecycle / state machine

```
pending ──▶ spec_ready ──▶ [HUMAN APPROVAL] ──▶ in_progress ──▶ done
                                                     │
                                                     └─▶ blocked
```

- Exactly **one feature is active at a time** (enforced by `init.sh`).
- **Full lane** adds the `spec_ready` + human-approval steps; **light lane**
  goes straight to `in_progress` after the orchestrator writes acceptance
  criteria.
- `feature_list.json` is the **index**; for full-lane features, `specs/<id>/`
  is the **source of truth**.
- A feature closes only on the validator's **APPROVED** verdict.

---

## Running it with Claude Code

1. Open a terminal in the harness directory and launch Claude Code:
   ```bash
   cd ~/dev/claude-sdd-harness
   claude
   ```
   `CLAUDE.md` is auto-loaded and pins the session to the **orchestrator** role.

2. Give it a task in plain language. The orchestrator runs its startup protocol
   (reads state, runs `./init.sh`), then picks a lane.

3. **Light lane** example prompt:
   > "Add a `GET /v1/health` endpoint to the backend that returns `{status: ok}`.
   > This is trivial — light lane."

4. **Full lane** example prompt:
   > "Implement the free-tier training analyst (Phase 2). This is substantial —
   > full lane."
   The orchestrator spawns `spec_creator`, which writes `specs/<id>/` and
   returns `spec_ready`. The orchestrator then **stops and asks you to approve**
   the spec. Nothing gets implemented until you say yes.

5. You can also invoke a subagent explicitly, e.g.:
   > "Use the validator subagent on feature 0007."

The anti-broken-telephone rule means the orchestrator will summarize what each
subagent wrote to disk in a few lines — it won't dump diffs or full specs into
the chat. Read the files in `specs/` and `progress/` for the detail.

---

## A worked example, end to end

Feature: **"User can log a training session"** (full lane).

1. **You:** "Implement session logging — full lane." 
2. **orchestrator:** runs `./init.sh` (green), creates the feature in
   `feature_list.json` as `pending`, spawns **spec_creator**.
3. **spec_creator:** writes `specs/0003-session-logging/` →
   `scope.yaml` (backend only, order 1, verify = ruff+mypy+pytest),
   `requirements.md` (`R1: The system SHALL persist a session with a timestamp
   and its line items…`), `design.md`, `tasks.md` (`T1 → R1, R2`). Returns
   `spec_ready -> specs/0003-session-logging/`.
4. **orchestrator:** STOPS. Summarizes the spec and asks you to approve.
5. **You:** "Approved."
6. **orchestrator:** sets the feature `in_progress`, spawns **coder**.
7. **coder:** implements the endpoint + Pydantic schemas + SQLAlchemy model +
   Alembic migration + pytest tests. Runs `./init.sh` (green). Writes
   `progress/impl_0003-session-logging.md` with a requirement→test map.
   Returns `done -> progress/impl_…md`.
8. **orchestrator:** spawns **validator**.
9. **validator:** checks files against `CHECKPOINTS.md`, runs `./init.sh`
   (green), confirms every `R` has a test. Writes
   `progress/review_0003-session-logging.md`, verdict **APPROVED**.
10. **orchestrator:** marks the feature `done`, appends a summary to
    `progress/history.md`, clears `progress/active.json`. Tells you it's done.

Every artifact — spec, implementation report, review — is on disk, committable,
and readable later. That trail is the whole point.

---

## The verification gate (`init.sh`) and hooks

**`init.sh`** is the single source of "is the world OK?". It:
1. Checks Python ≥ 3.12 and (warns on) Poetry.
2. Confirms the base harness files exist.
3. Validates `feature_list.json` (parses; **at most one** `in_progress`; all
   statuses valid).
4. Detects whether the target repos actually contain Python source yet.
5. **Only if code exists**, runs `ruff`, `mypy` (on `app/` or `src/`), and
   `pytest` from the primary repo. In the empty bootstrap state it passes with
   `[WARN]`s instead of failing — so the gate never blocks you before there's
   anything to check.

**Hooks** (`.claude/settings.json`) make verification non-optional, because the
harness runs them, not the agent:
- **PostToolUse** (matcher `Edit|Write|MultiEdit`): runs the test suite after
  any file edit and shows the tail. Skips gracefully during bootstrap.
- **Stop**: before the session can end, runs `./init.sh`. If it fails, the hook
  exits non-zero and **forces the session to keep working** until it's green.
  A `stop_hook_active` guard prevents an infinite loop.

Unlike instructions in `CLAUDE.md` (advisory, and ignorable in a long session),
hooks are **deterministic** — they run every time, no matter what the model
"decides".

---

## File-by-file reference

| Path | Purpose |
|---|---|
| `.claude/agents/orchestrator.md` | Coordinator role (the pinned main session). |
| `.claude/agents/spec_creator.md` | Writes `specs/<id>/` for full-lane features. |
| `.claude/agents/coder.md` | Implements one feature with tests. |
| `.claude/agents/validator.md` | Reviews and emits APPROVED / CHANGES_REQUESTED. |
| `.claude/settings.json` | PostToolUse + Stop hooks; permission allow-list. |
| `CLAUDE.md` | Auto-loaded session contract; pins the orchestrator role. |
| `AGENTS.md` | Navigation map, hard rules, standard flow. |
| `CHECKPOINTS.md` | Reusable review baseline the validator walks. |
| `repos.json` | The repos this harness drives + their verify commands. |
| `feature_list.json` | Feature index and state (`pending`/`in_progress`/`done`/`blocked`). |
| `init.sh` | The verification gate. |
| `templates/` | Skeletons the spec_creator fills (`scope.yaml`, `requirements.md`, `design.md`, `tasks.md`). |
| `docs/` | `architecture.md`, `conventions.md`, `verification.md`, `knowledge-pack.md`. |
| `specs/<id>/` | The four spec files for a full-lane feature — the source of truth. |
| `progress/active.json` | The currently active feature, or idle. |
| `progress/current.md` | Scratchpad for the in-flight session. |
| `progress/history.md` | Append-only log of closed features. |
| `progress/impl_<id>.md` | The coder's implementation report. |
| `progress/review_<id>.md` | The validator's verdict and coverage tables. |

---

## Troubleshooting

**The Stop hook won't let the session end.** That's by design — `./init.sh` is
red. Run it yourself, read the failing block, fix it (or fix the feature state),
then end the session.

**`init.sh` fails on `jq: command not found`.** Install jq (`brew install jq`).
The gate and the Stop hook both depend on it.

**Quality gates are skipped with a bootstrap WARN.** Expected until the target
repo has `.py` files and Poetry is installed. Once code exists, the gate
enforces ruff/mypy/pytest automatically.

**The orchestrator started editing code directly.** It shouldn't — that's a
hard rule in `CLAUDE.md` and `orchestrator.md`. Remind it to delegate to the
`coder` via the `Task` tool. If it persists, re-open the session so `CLAUDE.md`
reloads.

**Two features are `in_progress`.** `init.sh` will FAIL. Set all but one back to
`pending` in `feature_list.json`.

**A subagent dumped its whole output into chat.** Remind it of the
anti-broken-telephone rule: write to disk, return one line. The role files
already specify this; a long session may have drifted.

---

## Extending it (v2, v3, …)

This harness is intentionally small so it can evolve. Ideas for later versions:

- **An `explorer` role** for parallel codebase investigation before a spec
  (the orchestrator can already spawn Claude Code's built-in Explore, but a
  dedicated role with a knowledge-pack-writing mandate is a natural v2).
- **Per-feature branch automation** in `scope.yaml` (`branch_hints` is already
  a field — wire it to actual git operations).
- **A metrics hook** that logs tokens/latency per session to a file, so you can
  see the real cost of each feature.
- **A `docs/knowledge-pack.md` that grows automatically** — have the validator
  append durable findings after each APPROVED feature.
- **Multi-language verify** — `repos.json` already supports per-repo verify
  commands; `init.sh` could run each repo's own gate.

Keep each version tagged and write down what changed and why. The evolution
itself is part of the story.

---

## Credits

Origin: the role/hook/disk-as-memory pattern is inspired by / forked from
**Bettatech**'s Claude Code subagent example. This version renames the roles
(orchestrator / spec_creator / coder / validator), adds a full spec layer with
EARS requirements, a two-lane calibration to control token cost, deterministic
verification hooks, and a graceful bootstrap gate. Ported and adapted for
macOS / POSIX shell and a Python/FastAPI + React stack by **Rubén Juárez Pérez**.
