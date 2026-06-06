# Conventions — coding standards

<!-- Living doc. Grows per project. Source code wins over this doc on disagreement.
     Replace this stub with the project's actual agreed conventions. -->

## Formatting & linting

- Linter and formatter of choice (e.g. **ruff** + black-compatible style for
  Python, **eslint** + **prettier** for TypeScript). All checks must pass clean.
- Type checker (e.g. **mypy** strict-ish for Python, **tsc** for TypeScript).
  Type hints / annotations throughout — no untyped public functions.

## Naming

Follow the language's idiomatic conventions. Be consistent within the project.

## Error handling

- Explicit errors. Catch specific exceptions, not bare `except:` / `catch (e)`.
- Errors cross layer boundaries as domain errors, translated to protocol errors
  at the edge (e.g. `HTTPException` at the router, not in a service).
- No silent failures — log or propagate.

## Schemas and types

- One schema per request/response shape. Don't leak internal models to external
  boundaries.

## Migrations

- Schema changes through a migration tool (e.g. Alembic). No raw DDL in
  application code.

## Tests

- Tests live alongside the feature they cover, mirroring the source tree.
- Every behavior change ships its test in the same change.
- Prefer fast, deterministic unit tests; mock external I/O and LLM calls.

## Complexity

- Split long procedural blocks into focused private functions.
- No deeply-stacked conditionals in long methods.

---
*This is a stub at bootstrap. Replace with real project conventions.*
