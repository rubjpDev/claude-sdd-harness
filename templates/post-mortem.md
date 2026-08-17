<!-- claude-sdd-harness — origin: inspired by / forked from Bettatech.
     Adapted for macOS / POSIX shell by Rubén Juárez Pérez. -->

<!-- Human-facing post-mortem of an incident, written by the validator after the
     review. Lives at specs/<incident-id>/post-mortem-<incident-id>.md.
     Style: bro (.claude/skills/bro/SKILL.md) — plain language, real snippets from
     the diff. Hard cap: ~1-2 screens.
     NO personal or payment data. Internal ids only. This file is committed. -->

# Post-mortem — <incident-id>

**What broke:** <one line, in the user's terms. What they saw.>

**Why:** <one line. The actual cause, not where the error surfaced.>

**What stops it now:** <one line. The fix, and the test that keeps it fixed.>

Verdict: <APPROVED / CHANGES_REQUESTED> · Impact: <who/what was affected, in shapes not names>

## Timeline

| When | What |
|---|---|
| <date / commit / deploy> | <what changed, or `unknown`> |
| <date> | first report |
| <date> | fixed |

## The bug

<Two or three sentences: the mechanism. Why the bad state could exist at all.>

```python
# the code as it was — the actual lines that were wrong
```

<What was wrong with that. One sentence.>

## The fix

```python
# the actual lines from the diff
```

<Why this is the cause and not the symptom. One or two sentences.>

## The test that keeps it fixed

```python
# the regression test
```

Fails without the fix: <how that was verified.>

## Data already affected

- <rows/records in a bad state, and whether a backfill ran, was deferred, or wasn't
  needed. `none` if the bug never persisted anything.>

## What would have caught it earlier

- <the missing test, check, constraint, alert or type. One line each. No blame,
  no "we should be more careful".>
