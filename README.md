# Agenic Pony System

Pony-flavored multi-agent project orchestration for people who like expressive tools and serious engineering.

This repository is the reusable system layer. The live runtime belongs inside each target project's `pony/` tree, so multiple projects can run in parallel without leaking coordination state into each other.

## Why This Exists

Most multi-agent setups fail in one of two ways:

- they feel cute but collapse under real software coordination
- they are technically serious but joyless to operate

Agenic Pony System aims for both:

- a clear, inspectable runtime model
- project-local state and launchers
- explicit queueing and stopping points
- operator-friendly pony identity, prompts, and transcript cues

If you like ponies, great. If you are a senior engineer who cares about reproducibility, isolation, and debuggability, that part is not optional.

## Core Ideas

- project-local runtime under `<project>/pony/`
- one reusable system repo, many isolated project installs
- explicit queue-driven execution
- transparent agent-originated requests
- launch surfaces for Warp and shell-based workflows

## Project Layout

The active runtime lives in the target project, not here.

Expected shape:

```text
<project-root>/
  pony/
    agents/
    assets/
    team.coordination/
    launch.prompts/
    launch.configs/
    scripts/
    work/
    worktrees/
    pony.system.config.yaml
```

That structure mirrors the real operating layout refined in live project use.

## What The Reusable System Provides

- project bootstrap scripts
- project-specific Warp launcher generation
- project-local shell launcher generation
- reusable pony audio assets and local alert wrappers
- reusable pony prompts
- root-detection and install logic for `codex-pony`
- design docs for runtime behavior and installation

## Current Direction

`codex-pony` is intended to become the bootstrap boundary:

- detect the enclosing project root
- check whether the project's `pony/` system is installed
- provision missing pieces when needed
- launch into the correct project-local runtime

That keeps runtime identity tied to the actual repo being worked on.

## Warp And Shell Launching

The safest model is project-specific launchers.

Examples:

- `Handshake Pony Team`
- `Project A Pony Team`
- `Project B Pony Team`

Each launcher binds to one explicit project root. That avoids ambiguous cross-project detection when multiple repos are open at once.

Shell launchers should exist too, so the system is not Warp-dependent.

## Quick Start

From inside a target project:

```bash
/path/to/agenic-pony-system/scripts/install-project.sh
/path/to/agenic-pony-system/scripts/install-warp-launch-configs.sh
```

Or explicitly:

```bash
/path/to/agenic-pony-system/scripts/install-project.sh /path/to/project
/path/to/agenic-pony-system/scripts/install-warp-launch-configs.sh /path/to/project
```

After project install, the project-local shell launchers live under:

```text
<project>/pony/bin/pony-team
<project>/pony/bin/pony-team-twi
<project>/pony/bin/pony-aj
<project>/pony/bin/ponyalert
<project>/pony/bin/ponydone
<project>/pony/assets/voices/
```

## Optional Zsh Support

The shell hook is optional convenience, not infrastructure.

Recommended one-line `.zshrc` pattern:

```zsh
[[ -f ./pony/scripts/pony.zsh.support.zsh ]] && source ./pony/scripts/pony.zsh.support.zsh
```

That keeps shell sugar project-local and avoids a giant home-directory alias block.

## Assumptions

- `codex` is available on `PATH`
- Git is available
- Warp launch configurations, when used on Windows/WSL, live at:
  `/mnt/c/Users/$USER/AppData/Roaming/warp/Warp/data/launch_configurations`
  or a custom `WARP_LAUNCH_CONFIG_DIR`

## Design Docs

- `docs/runtime-loop.md`: queue-driven runtime, stopping points, and pending-agent request behavior
- `docs/project-installation.md`: project root detection, project-local pony layout, launcher markers, and optional shell support

## Status

This repo is early, but the design direction is concrete:

- keep the runtime project-local
- keep scheduling and stopping behavior explicit
- keep agent requests visible to the user
- keep the system fun without sacrificing operator clarity
