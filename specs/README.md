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

`<feature-id>` is the stable slug used everywhere — your ticket id is the natural
choice (e.g. `G-1000`, `proj-0001-user-auth`).
The `spec_creator` writes these from the `templates/`. The folder is the
**source of truth** for the feature.

## Incidents

An incident gets its own folder too, named after the ticket id:

```
specs/<incident-id>/                    # e.g. specs/INC-I303/
  diagnosis-<incident-id>.md            # the triage agent's contract: repro, root
                                        # cause, blast radius, regression test
  post-mortem-<incident-id>.md          # HUMAN write-up, after the review
```

The diagnosis is to an incident what the spec is to a feature: **the contract the
coder implements against**. It is written before any code, by `triage`, and it is
the source of truth for what "fixed" means.

The post-mortem replaces `walkthrough.md` for incidents — same `bro` styling and
real snippets, post-mortem shape: what broke, why, what stops it now, a timeline,
what data was affected, and what would have caught it earlier. Both files carry the
incident id in the filename because you end up with several open at once.

If `triage` returns `escalate`, the `spec_creator` writes the four spec files into
this **same** folder, next to the diagnosis.

**No production data in either file.** These are committed: internal ids only, never
names, emails, account names, card numbers or tokens.

## Light-lane features

Trivial features do **not** get a `specs/` folder. They live only as an entry in
`feature_list.json` with an `acceptance` array — and therefore no `brief.md` /
`walkthrough.md` either. Ask the orchestrator explicitly if a light-lane change
still deserves a walkthrough.

## Relationship to feature_list.json

`feature_list.json` is the **index**; `specs/<id>/` is the **source of truth**
for full-lane work. When they disagree, the spec folder wins for content and
`feature_list.json` is corrected for status.
