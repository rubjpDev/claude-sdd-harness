# Verification — how to prove the work

<!-- Living doc. Grows per project. -->

## The gate

```bash
./init.sh
```

`init.sh` is the single source of truth for "is the tree healthy". It checks the
toolchain, harness files, `feature_list.json` validity, and — once source code
exists in the declared repos — runs the quality gates. In the empty bootstrap
state it passes with WARNs.

## Quality gates (once code exists)

Configured in `repos.json` under `default_verify`. Default for a Python/FastAPI
backend:

```bash
poetry run ruff check .     # lint/format — must be clean
poetry run mypy app         # types — must be clean
poetry run pytest -q        # tests — must be green
```

Default for a TypeScript/React frontend:

```bash
npm run type-check
npm run build
```

## Coverage

- Target ≥ 70% line coverage (adjust per project):
  ```bash
  poetry run pytest --cov=app --cov-report=term-missing
  ```

## Local stack

Document how to run the full local stack here (e.g. `docker compose up`).

## Definition of verified

Every requirement (`R` id) or acceptance criterion is backed by a test or a
declared verification path, and `./init.sh` exits green.
