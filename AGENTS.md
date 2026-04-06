# AGENTS.md

## Purpose

This repository contains the standalone Agenic Pony System. It is not tied to Handshake or any single project.

## Rules

- Keep all project runtime state outside this repo unless it is a reusable template.
- Default per-project state root: `.agenic-pony/` under the target project root.
- Do not bake in Handshake paths, task state, prompts, or coordination files.
- If a script needs to know the target project, detect the current git repo root first and fall back to the current directory.
- If a script needs branch context, use the current branch of the target project worktree.
- Launchers should prefer using the current project worktree directly unless a later feature explicitly asks for separate worktrees.

## Layout

- `scripts/`: bootstrap, install, and config-generation utilities
- `pony/scripts/`: runtime helpers used by launch configurations
- `pony/bin/`: small user-facing utilities
- `pony/launch.prompts/`: generic baseline prompts, with no project state baked in

## Blank-State Requirement

Every new project must start with blank pony state. Only generic templates may be copied into a new project. No stale mailbox, todo, decision, or assignment content from another project should appear unless the user explicitly imports it.
