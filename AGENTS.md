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
- **APPROVED** → `done`, append `progress/history.md`, clear `progress/active.json`.
- **CHANGES_REQUESTED** → spawn `coder` again with the review.
- **Blocked** → `blocked`, record open question, ask human.

## Cross-repo order

Backend first, then frontend (code-first → generated typed client). Configured
in `scope.yaml` per feature; the `order` field is authoritative.

## Model & effort tiering

Heavy reasoning (orchestration, spec authoring, review) runs on Opus; mechanical
implementation runs on Sonnet to control token cost. The deliberate split:

| Agent | Model | Effort |
|---|---|---|
| `orchestrator` (main session) | Opus 4.8 | high |
| `spec_creator` | Opus 4.8 | high |
| `coder` | Sonnet 4.6 | medium |
| `validator` | Opus 4.8 | high |

- The **orchestrator's tier is set at launch** via `./run.sh` (it exports
  `CLAUDE_CODE_EFFORT_LEVEL=high` and launches `claude --model opus`). Its
  frontmatter stays `model: inherit`.
- **Per-agent tiers live in each agent's frontmatter** (`model:` + `effort:`).
- **Never set `CLAUDE_CODE_SUBAGENT_MODEL`** — it forces ALL subagents to a
  single model and breaks the per-agent tiering.
