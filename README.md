# Agenic Pony System

Standalone bootstrap and launch tooling for a pony-flavored multi-agent workflow.

This repo is intentionally project-agnostic. It does not carry Handshake coordination state, workfiles, or launch bindings.

## What It Does

- installs Warp launch configurations for a chosen project
- creates blank project-local coordination state under `.agenic-pony/`
- starts pony sessions against the current project worktree
- keeps workers on the current project branch when launched inside a git repo

## Project State

Per-project state lives in the target project, not in this repo:

```text
<project-root>/.agenic-pony/
  agent-work/
  team.coordination/
```

That keeps every new project blank by default and prevents state leakage across repos.

## Quick Start

From the target project:

```bash
/home/ggb66/dev/agenic-pony-system/scripts/install-warp-launch-configs.sh
```

Or explicitly:

```bash
/home/ggb66/dev/agenic-pony-system/scripts/install-warp-launch-configs.sh /path/to/project
```

That will:

1. detect the project root and current branch
2. create `.agenic-pony/` if it does not exist
3. install Warp launch configs for the project

## Direct Launch

```bash
/home/ggb66/dev/agenic-pony-system/pony/scripts/start-session.sh TWILIGHT_SPARKLE /path/to/project
/home/ggb66/dev/agenic-pony-system/pony/scripts/start-session.sh APPLEJACK /path/to/project
```

## Assumptions

- `codex` is available on `PATH`
- Warp launch configurations live at:
  `/mnt/c/Users/$USER/AppData/Roaming/warp/Warp/data/launch_configurations`
  or a custom `WARP_LAUNCH_CONFIG_DIR`

## Notes

- The generated launch configs point all ponies at the active project root.
- No project-specific state is committed here unless you choose to add templates later.

## Design Docs

- `docs/runtime-loop.md`: queue-driven runtime, stopping points, and pending-agent request behavior
- `docs/project-installation.md`: project root detection, project-local pony layout, launcher markers, and optional shell support
