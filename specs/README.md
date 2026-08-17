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
  brief.md           # HUMAN summary of the spec, written before the coder starts
  walkthrough.md     # HUMAN walkthrough of the change, written after the review
```

`scope.yaml` / `requirements.md` / `design.md` / `tasks.md` are written **for the
coder**: exhaustive and long. `brief.md` and `walkthrough.md` are written **for
you**: ~1 screen each, diagrams and real snippets instead of prose.

| File | Written by | When | Style |
|---|---|---|---|
| `brief.md` | `spec_creator` | with the spec, before the approval gate | `no-ai-slop`, Mermaid diagram + change table |
| `walkthrough.md` | `validator` | after the review | `bro`, real snippets from the diff, PR-review tone |

Both are **views**, never a source of truth: if a summary disagrees with the spec
or the code, the spec/code wins and the summary is corrected. Both skills ship
bundled in `.claude/skills/` — nothing to install.

`<feature-id>` is the stable slug used everywhere (e.g. `proj-0001-user-auth`).
The `spec_creator` writes these from the `templates/`. The folder is the
**source of truth** for the feature.

## Light-lane features

Trivial features do **not** get a `specs/` folder. They live only as an entry in
`feature_list.json` with an `acceptance` array — and therefore no `brief.md` /
`walkthrough.md` either. Ask the orchestrator explicitly if a light-lane change
still deserves a walkthrough.

## Relationship to feature_list.json

`feature_list.json` is the **index**; `specs/<id>/` is the **source of truth**
for full-lane work. When they disagree, the spec folder wins for content and
`feature_list.json` is corrected for status.
