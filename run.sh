#!/usr/bin/env bash
# Launch Claude Code as the orchestrator on Opus 5 / medium effort.
# spec_creator runs Opus/high per its frontmatter; tutor stays Opus/high;
# coder & validator run Sonnet/medium per their frontmatter.
set -eu
export CLAUDE_CODE_EFFORT_LEVEL=medium
# IMPORTANT: do NOT set CLAUDE_CODE_SUBAGENT_MODEL — it would force ALL
# subagents to a single model and break the per-agent tiering.
exec claude --model claude-opus-5 "$@"
