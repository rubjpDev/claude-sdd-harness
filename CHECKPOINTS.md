# CHECKPOINTS.md — reusable review baseline

<!-- claude-sdd-harness — origin: inspired by / forked from Bettatech.
     Adapted for macOS / POSIX shell by Rubén Juárez Pérez. -->

The `validator` walks this list for every feature, marking `[x]` (pass) or
`[ ]` (fail / not applicable, with a note). "(full lane)" items apply only to
full-lane features.

## Spec and scope (full lane)

- [ ] A dedicated `specs/<id>/` folder exists.
- [ ] `scope.yaml` declares ticket id, type, lane, affected repos, order, and per-repo verify commands.
- [ ] `requirements.md` uses strict EARS with stable `R` ids.
- [ ] `tasks.md` uses stable `T` ids, each mapped to one or more `R` ids.
- [ ] Human approval happened **before** implementation began.

## Repository boundaries

- [ ] Only the repos declared in `scope.yaml` were changed.
- [ ] The declared repo order was respected.
- [ ] No harness artifacts were created inside the repos being developed.

## Implementation quality

- [ ] Follows `docs/conventions.md`.
- [ ] No scope creep — no unrelated endpoints or refactors.
- [ ] Explicit error handling — no bare `except`, no silent failures.
- [ ] Large changes split into focused functions; no 100-line methods.
- [ ] Comments appear only where the code genuinely needs them.
- [ ] Type hints throughout.

## Verification and traceability

- [ ] Every requirement / acceptance criterion has a test or declared verification path.
- [ ] Test suite is green.
- [ ] Linter is clean.
- [ ] Type checker is clean.
- [ ] `./init.sh` exits green.
- [ ] `impl_<id>.md` contains a requirement → test map.
- [ ] `review_<id>.md` records an explicit verdict.

## Session hygiene

- [ ] `feature_list.json` status matches reality.
- [ ] `progress/active.json` matches the active feature.
- [ ] `progress/current.md` was updated during work.
- [ ] `progress/history.md` was updated on close.
