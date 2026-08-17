# AGENTS.md — claude-sdd-harness navigation map

<!-- claude-sdd-harness — origin: inspired by / forked from Bettatech.
     Adapted for macOS / POSIX shell by Rubén Juárez Pérez. -->

Runtime-agnostic map of how work flows through this harness.

Runtime: **macOS / Linux, bash or zsh. POSIX shell only.**

## Before starting

1. Run `./init.sh` — the verification gate. Red → stop.
2. Read `progress/current.md`.
3. Read `progress/active.json`.
4. Read `feature_list.json`.
5. Know the spec convention: full-lane features live in `specs/<id>/` (see `specs/README.md`).

## Repository map

Declared in `repos.json`. Configure it per project. The shipped `repos.json` is
a sample (`example-backend` + `example-frontend`) — replace it with your own
repos. Example shape:

| id | repo | role | stack |
|---|---|---|---|
| `backend` | example-backend | main-service | Python 3.12, FastAPI, Pydantic v2, SQLAlchemy, Alembic, PostgreSQL, Redis, Poetry, pytest |
| `frontend` | example-frontend | client | React, Vite, TypeScript, Tailwind |

The harness lives in its own directory and coordinates repos from here. **No
harness artifacts inside the repos being developed.**

## Hard rules

- One feature at a time.
- Full lane: `specs/<id>/` is source of truth; `feature_list.json` is the index.
- No harness artifacts (`.claude/`, `specs/`, `progress/`, `templates/`, `init.sh`, …) inside repos being developed.
- Don't skip the spec phase for full-lane work.
- Don't skip the human approval gate.
- Outputs on disk, not in chat.
- Validate only repos actually affected.

## State model

```
pending -> spec_ready -> [HUMAN APPROVAL] -> in_progress -> done
                                             \-> blocked
```

## Standard flow

- **New work** → orchestrator picks the lane.
  - Light → write `acceptance` criteria → spawn `coder`.
  - Full → spawn `spec_creator` → `spec_ready` → STOP, ask human.
- **Spec approved** → `in_progress` → spawn `coder`.
- **Coder `done`** → spawn `validator`.
- **APPROVED** (validator has appended any durable findings to `docs/knowledge-pack.md`) → `done`, append `progress/history.md`, clear `progress/active.json`.
- **CHANGES_REQUESTED** → spawn `coder` again with the review.
- **Blocked** → `blocked`, record open question, ask human.

### Human-facing summaries (full lane)

Two files in `specs/<id>/` are written for the **human**, ~1 screen each:

- `brief.md` — by `spec_creator`, before the approval gate. Applies the bundled
  `no-ai-slop` skill; Mermaid diagram + "what changes" table instead of prose.
- `walkthrough.md` — by `validator`, after the review. Applies the bundled `bro`
  skill; real snippets from the diff, explained like a PR walkthrough to a senior.

Views, never sources of truth — spec and code win, the summary gets fixed.
Light lane skips both unless asked.

### Architecture map

`/arch-map` (bundled skill) generates two committed views of the code:
`docs/arch-map.json` — `{nodes, edges, flows}`, read by the `spec_creator` in
place of a broad exploration pass — and `docs/generated/architecture.html`, the
interactive diagram for humans. Both are **generated**: never hand-edit them,
source code wins, and the stored commit SHA says how stale they are (`init.sh`
warns past 20 commits). Re-runs update in place; they never rebuild from scratch.

### Ponytail is on by default

`spec_creator` and `coder` run ponytail (lazy-senior-dev) by default; the skill is
bundled in `.claude/skills/`, nothing to install. The `validator` reviews
accordingly: minimal is not a finding. Disable per-task with the literal token
`ponytail off` in the `Task` prompt.

### Tutor mode (delivery mode, orthogonal to lane)

When a feature carries `"mode": "tutor"`, the **delivery** step uses `tutor`
instead of `coder`: the human writes the code, the harness teaches and verifies.
Lane is unchanged (it still decides `spec_creator` + the approval gate).

- **Tutor-mode delivery** → orchestrator sets `in_progress` (the `tutor` cannot) →
  spawn `tutor` → `tutorial -> progress/tutorial_<id>.md` → **STOP** → [HUMAN writes
  the code + `progress/impl_<id>.md`] → spawn `validator` (unchanged) → APPROVED →
  `done`.
- **CHANGES_REQUESTED** → relay the review; re-spawn `tutor` only if the human wants
  the concept explained. The `tutor` never edits code or state.

## Cross-repo order

Backend first, then frontend (code-first → generated typed client). Configured
in `scope.yaml` per feature; the `order` field is authoritative.

## Model & effort tiering

Orchestration, spec authoring, and teaching (heaviest reasoning) run on Opus 5;
review and mechanical implementation run on Sonnet to control token cost.
The deliberate split:

| Agent | Model | Effort |
|---|---|---|
| `orchestrator` (main session) | Opus 5 | medium |
| `spec_creator` | Opus 5 | high |
| `coder` | Sonnet 5 | medium |
| `tutor` (tutor mode) | Opus 5 | high |
| `validator` | Sonnet 5 | medium |

- `tutor` replaces `coder` when a feature sets `mode: tutor`: it produces a learning
  tutorial and the human writes the code. Teaching is the heaviest reasoning, so it
  stays on Opus at high effort.
- The **orchestrator's tier is set at launch** via `./run.sh` (it exports
  `CLAUDE_CODE_EFFORT_LEVEL=medium` and launches `claude --model claude-opus-5`). Its
  frontmatter stays `model: inherit`.
- **Per-agent tiers live in each agent's frontmatter** (`model:` + `effort:`).
- **Never set `CLAUDE_CODE_SUBAGENT_MODEL`** — it forces ALL subagents to a
  single model and breaks the per-agent tiering.
