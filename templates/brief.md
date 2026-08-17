<!-- claude-sdd-harness — origin: inspired by / forked from Bettatech.
     Adapted for macOS / POSIX shell by Rubén Juárez Pérez. -->

<!-- Human-facing summary of the spec, written BEFORE the coder starts.
     Hard cap: ~1 screen. If it doesn't fit, cut prose, never diagrams.
     Style: no-ai-slop (.claude/skills/no-ai-slop/SKILL.md). Short sentences,
     no filler, no "it's worth noting that". -->

# Brief — <feature-id>

**What we're building:** <one or two sentences. Plain language.>

**Why:** <one sentence. The problem it solves.>

## Flow

```mermaid
%% The main flow, end to end. Swap for erDiagram / sequenceDiagram when that
%% fits the feature better. One diagram, two at most.
flowchart LR
  A[caller] --> B[entry point] --> C[(store)]
```

## What changes

| Where | What | Why |
|---|---|---|
| `path/to/file` | create / modify | <half a line> |

## Decisions that matter

- <decision> — <why, in one line. Only the ones a reviewer would question.>

## Out of scope

- <what we are deliberately NOT doing>

## Open questions

- <blocking question, or `none`>
