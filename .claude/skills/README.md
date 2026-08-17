# Bundled skills

Vendored so the harness works out of the box — no plugin install needed. Claude
Code auto-discovers `.claude/skills/*/SKILL.md` when launched from this repo
(`./run.sh`), for the orchestrator and every subagent.

| Skill | Invoke | Origin |
|---|---|---|
| `ponytail` | `/ponytail [lite\|full\|ultra]` | [ponytail](https://github.com/DietrichGebert/ponytail) plugin v4.7.0 — MIT (`ponytail/LICENSE`) |
| `ponytail-audit` | `/ponytail-audit` | idem |
| `ponytail-review` | `/ponytail-review` | idem |
| `no-ai-slop` | `/no-ai-slop` | community skill, MIT-style |
| `bro` | `/bro` | community skill, MIT |
| `arch-map` | `/arch-map` | this harness — generates `docs/arch-map.json` + `docs/generated/architecture.html` |

All but `arch-map` are verbatim copies of upstream. To update, re-copy from upstream rather than
editing in place. The `ponytail` plugin's hooks and statusline are **not**
vendored — only the skill prompts, which is all the harness needs.

`ponytail` **is** on by default for `spec_creator` and `coder` (the rule lives in
their definitions; the `validator` reviews accordingly). Disable it per task with
the literal token `ponytail off` in the `Task` prompt. `no-ai-slop` and `bro` are
applied automatically too, but only to the two human-facing summaries
(`specs/<id>/brief.md` and `specs/<id>/walkthrough.md`). The rest run only when
you invoke them.
