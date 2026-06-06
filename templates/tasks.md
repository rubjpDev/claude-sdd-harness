<!-- rjp-harness-v1 — origin: inspired by / forked from Bettatech.
     Adapted for macOS / POSIX shell by Rubén Juárez Pérez. -->

# Tasks — <feature-id>

Each task has a stable id (`T1`, `T2`, …) and references one or more `R` ids
from `requirements.md`. The `coder` executes these in order.

| Task | Description | Covers | Done |
|---|---|---|---|
| **T1** | <implementation step> | R1 | [ ] |
| **T2** | <implementation step + its test> | R1, R2 | [ ] |

## Notes

- Every task that adds behavior includes its test before the next task begins.
