#!/usr/bin/env bash
# Launch Claude Code as the orchestrator on Opus 4.8 / high effort.
# spec_creator & validator inherit Opus/high per their frontmatter;
# coder runs Sonnet/medium per its frontmatter.
set -eu
export CLAUDE_CODE_EFFORT_LEVEL=high
# IMPORTANT: do NOT set CLAUDE_CODE_SUBAGENT_MODEL — it would force ALL
# subagents to a single model and break the per-agent tiering.
exec claude --model opus "$@"
