---
name: arch-map
description: Map the architecture of the repos declared in repos.json into two artifacts — docs/arch-map.json (machine-readable {nodes, edges, flows} for agents) and docs/generated/architecture.html (self-contained interactive diagram for humans, with per-node "what it does / how it's built" panels and step-through flows). Use when the user says "/arch-map", "arch map", "genera el diagrama de arquitectura", "map the architecture", "regenerate the architecture diagram", or when the stored map is stale after a structural change.
argument-hint: "[--json-only|--html-only]"
---

# arch-map

Two outputs, one analysis:

| Output | For | Committed |
|---|---|---|
| `docs/arch-map.json` | agents — replaces re-exploring the repo | yes |
| `docs/generated/architecture.html` | humans — interactive diagram | yes |

Both are **generated views**. Source code wins on disagreement.

## Incremental by default — do NOT rebuild from scratch

If either file already exists, **update it, never regenerate it.** Rebuilding a
full repo map costs a lot of tokens for a diff that is usually three nodes.

1. Read `docs/arch-map.json` and take `generated_at_commit`.
2. `git -C <repo> diff --name-status <stored-sha>..HEAD` for each repo in
   `repos.json`. That diff **is** your scope of work.
3. Empty diff → say "map is current", change nothing, stop. That's the whole run.
4. Otherwise touch only what the diff implies: add/remove/rename nodes and edges
   for changed files, update the flows those files take part in, bump
   `generated_at` / `generated_at_commit`. Everything the diff didn't touch stays
   byte-identical.
5. Same for the HTML: `Edit` the affected nodes/edges/flows in place, and rewrite
   only the `PROSE` entries whose node the diff touched. Never `Write` the whole
   file when it already exists — the prose is the expensive part of it.

Full rebuild only when: no map exists, the stored SHA is unreachable
(`git cat-file -e` fails), or the user explicitly asks for a clean rebuild.

## Analysis

Read `repos.json` for the repos, roles and stacks. Then map what is actually
there — entry points, routes/handlers, modules, data stores, external services,
background jobs, cross-repo calls. Glob/Grep the real tree; never infer structure
from the docs. Skip vendor dirs, `node_modules`, `.venv`, build output, tests
(tests are not architecture).

Granularity: a node is something a person would name in a whiteboard sketch — a
module, a service, a table group, an external API. Not one node per file. If the
map has more than ~40 nodes you went too fine; collapse.

## `docs/arch-map.json`

```json
{
  "generated_at": "2026-08-17T10:00:00Z",
  "generated_at_commit": { "backend": "<sha>", "frontend": "<sha>" },
  "nodes": [
    { "id": "api.auth", "label": "Auth routes", "repo": "backend", "kind": "module",
      "path": "app/auth.py", "desc": "One line: what it does." }
  ],
  "edges": [
    { "from": "api.auth", "to": "db.users", "kind": "reads-writes", "desc": "One line." }
  ],
  "flows": [
    { "id": "login", "label": "User login",
      "steps": ["client.login-form", "api.auth", "db.users", "api.auth", "client.login-form"],
      "desc": "One line." }
  ]
}
```

Rules: `id` is a stable dotted slug — **never renumber or rename an existing id**,
agents and the HTML both key off it. `kind` is free-form but consistent
(`module`, `store`, `external`, `job`, `ui`). `steps` are node ids in order, and
every step id must exist in `nodes`. `desc` is one line, always — this file is
read into an agent's context, so every extra line is a token tax on every spawn.
Keep keys sorted and formatting stable so diffs stay small.

## `docs/generated/architecture.html`

One self-contained file: no CDN, no external CSS/JS/fonts, everything inline. It
must open from `file://` with no server. Two script literals at the top:

- `const MAP = {…}` — a mirror of `arch-map.json`. These two never disagree.
- `const PROSE = { "<node-id>": { does, built } }` — the explanations. **HTML only,
  never in the JSON**: agents read the JSON on every spawn, so prose there is a
  token tax on work that doesn't need it. This file is the one you open yourself.

- **Diagram**: nodes + directed edges, grouped visually by repo. Inline SVG, hand-
  laid or a small force/layered layout in plain JS — no graph library.
- **Flow panel** on the right: one entry per flow. Click → highlight the full path
  (nodes + edges in order, dim the rest), click again → clear.
- **Tooltip** on hover over any node: label, repo, path, `desc`.
- Responsive: panel drops below the diagram under ~800px. The diagram scrolls
  inside its own container; the page body never scrolls sideways.
- Theme-aware: define the light palette as CSS custom properties on `:root`, and
  override them under `@media (prefers-color-scheme: dark)`. Explicit background
  and text color on `body` — never inherit.
- Clean and plain: system font stack, generous whitespace, no animation beyond a
  150ms highlight transition. It's a diagram, not a landing page.

Accessibility is not optional: nodes reachable by keyboard (`tabindex`), flow
entries are real `<button>`s, and highlight state is not conveyed by color alone
(also stroke width / opacity).

### Explanation panel — two registers

Selecting a node (or a flow) fills a panel with two tabs. Same subject, two
audiences; that split is what makes the diagram discussable instead of decorative.

- **What it does** — plain language, for someone who has never opened the file. No
  type names, no class names, no framework vocabulary unless the word is the only
  honest one. Write it with the bundled `no-ai-slop` skill (read
  `.claude/skills/no-ai-slop/SKILL.md`): short sentences, concrete nouns, no
  "serves as a central component for". 2-4 sentences, hard cap.
- **How it's built** — the implementation: entry points, the pattern used, what it
  depends on, real symbol and file names. Terse and technical. 2-4 sentences.
- Also worth a line when true: **what's currently wrong with it** — a known gap,
  a TODO that matters, a `ponytail:` shortcut and its ceiling. Only when real;
  never invent a weakness to fill the slot.
- Nothing is written for a node you did not read. An empty `PROSE` entry renders
  as "not documented yet" — that is a fine state, a fabricated paragraph is not.
- **Prose survives regeneration.** On an incremental update, only rewrite the
  entries for nodes the diff actually touched. Existing prose for untouched nodes
  is left byte-identical, even on a full rebuild of the layout.

### Flow stepping

The flow panel walks the flow, it doesn't only highlight it — `steps` is already
an ordered array, so this is an index and two buttons:

- **Step** advances one hop: highlight step `n`'s node and the edge into it, dim
  the rest, and show that hop in the panel ("3/5 — `api.auth` → `db.users`").
- **Resume** highlights the whole path at once; **Reset** clears the view.
- Keyboard: `←` / `→` step, `Esc` resets, when a flow is selected.

## After generating

Report in three lines: nodes/edges/flows counts, what changed since the stored
SHA (or "full build"), and the two paths. Nothing else — no tour of the
architecture, the artifacts are the deliverable.

The `docs/knowledge-pack.md` index already points at both files; don't append the
map into it. It's a separate file precisely so it doesn't get read on every spawn
when nobody needs it.
