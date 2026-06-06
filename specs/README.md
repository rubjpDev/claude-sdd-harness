# specs/ — the spec folder convention

<!-- claude-sdd-harness — origin: inspired by / forked from Bettatech.
     Adapted for macOS / POSIX shell by Rubén Juárez Pérez. -->

## Full-lane features

Each substantial (full-lane) feature lives in its own folder:

```
specs/<feature-id>/
  scope.yaml         # operational envelope: repos, order, verify, out-of-scope
  requirements.md    # strict EARS, stable R ids
  design.md          # modules, files, decisions, rejected alternatives, risks
  tasks.md           # stable T ids, each mapping to one or more R ids
```

`<feature-id>` is the stable slug used everywhere (e.g. `proj-0001-user-auth`).
The `spec_creator` writes these from the `templates/`. The folder is the
**source of truth** for the feature.

## Light-lane features

Trivial features do **not** get a `specs/` folder. They live only as an entry in
`feature_list.json` with an `acceptance` array.

## Relationship to feature_list.json

`feature_list.json` is the **index**; `specs/<id>/` is the **source of truth**
for full-lane work. When they disagree, the spec folder wins for content and
`feature_list.json` is corrected for status.
