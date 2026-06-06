# Architecture — what "good work" means here

<!-- Living doc. Grows per project. Source code wins over this doc on disagreement.
     Replace this stub with the actual architecture of the project. -->

## Intended structure

Document the system's architectural layers and the rules between them. Example
for a FastAPI/Python backend:

```
routers  ->  services  ->  repositories  ->  models
(HTTP)       (business)    (data access)     (ORM / domain)
```

- **routers** — HTTP edge. Parse/validate with Pydantic v2, call services, shape responses. No business logic.
- **services** — business logic. Deterministic, testable, framework-light.
- **repositories** — data access only. No business rules.
- **models** — ORM models and domain types.

## Boundaries

- Types / schemas at every external boundary.
- Code-first API contract: the backend generates the schema; clients consume it.
- Async for I/O-bound paths; don't make trivially-synchronous code async.

## Key separation of concerns

Keep deterministic logic separate from external I/O (LLM calls, third-party
APIs, file I/O). The seam lets you mock, cache, and swap independently.

## Persistence

Document the data stores and their role. Note the migration strategy (e.g.
Alembic for schema changes — never raw DDL in application code).

---
*This is a stub at bootstrap. Replace with real project architecture.*
