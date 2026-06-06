# Current working note

- **Date:** 2026-06-03
- **Active feature:** none
- **Status:** harness bootstrapped (idle)
- **Next step:** populate `docs/knowledge-pack.md` with project facts, then define the first feature and choose its lane.

---

## Bootstrap summary

Spec-driven, role-based agentic harness installed as a standalone directory
(`claude-sdd-harness`), living at the same level as the repos it coordinates.
Four roles: `orchestrator`, `spec_creator`, `coder`, `validator`. Two lanes
(light / full) with a human approval gate before full-lane implementation.
Verification gate: `./init.sh`. Hooks in `.claude/settings.json` enforce it
on every edit and on session stop.

The harness is project-agnostic. `repos.json` and `feature_list.json` are the
project-specific configuration layer. Current config targets the YATA project
(`yata-backend` + `yata-frontend`).

Origin: inspired by / forked from Bettatech. Adapted for macOS / POSIX shell
by Rubén Juárez Pérez.

---

## Model & effort tiering (configured 2026-06-04)

Per-agent model/effort tiering applied. Table: orchestrator Opus 4.8/high
(set at launch via `run.sh`), spec_creator Opus 4.8/high, coder Sonnet 4.6/medium,
validator Opus 4.8/high.

**Step 0 findings:**
- **Model identifiers:** used **aliases** (`opus`, `sonnet`) rather than pinned
  strings. In this Claude Code version `opus` resolves to the latest Opus tier
  (Opus 4.8) and `sonnet` to the latest Sonnet tier (Sonnet 4.6), so the aliases
  correctly target 4.8 / 4.6 and track the intended tier going forward. Pinned
  IDs (`claude-opus-4-8`, `claude-sonnet-4-6`) remain available if exact pinning
  is ever needed.
- **`effort` frontmatter:** added (`high` / `medium`). Accepted values
  `low|medium|high`. Frontmatter parses; gate stays green.
- **`model:`-ignored issue:** does **not** reproduce in this version —
  subagent frontmatter `model:` is honored. The Step 4 delegation workaround
  (passing the model explicitly in the `Task` call) is therefore **precautionary,
  not strictly necessary**; kept as a belt-and-suspenders safeguard. Still verify
  the actual model on the first spawn of each subagent and record it here.

**Deviation from prompt:** none material. PyYAML is not installed locally, so the
frontmatter was validated by inspection (simple `key: value` lines) rather than a
strict `yaml.safe_load`; `./init.sh` passes (EXIT=0).
