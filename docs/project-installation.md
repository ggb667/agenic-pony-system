# Project Installation Design

This document defines how the standalone Agenic Pony System should bind itself to a specific project and provision that project's pony infrastructure.

## Core Rule

The pony system is project-local.

That means the runtime layout belongs under the target project's `pony/` tree, not under a global directory and not under a hidden alternate state root.

Examples:

- `gitRepoA/pony/...`
- `gitRepoB/pony/...`
- `/home/ggb66/dev/Handshake/pony/...`

Not:

- `gitRepoA/.agenic-pony/...`
- `gitRepoB/.agenic-pony/...`

## Project Root Detection

`codex-pony` should determine the active project by walking upward from the current directory.

Preferred behavior:

1. start from `$PWD`
2. if inside a git worktree, resolve the enclosing repository root
3. treat that repository root as the candidate project root
4. look for project-local pony installation state under `<project-root>/pony/`

This keeps pony runtime state tied to the actual project the user is working in.

## Project-Local Pony Layout

The reusable system may live in its own repository, but the active project must own the runtime layout.

Expected project-local structure:

```text
<project-root>/
  pony/
    agents/
    team.coordination/
    launch.prompts/
    launch.configs/
    scripts/
```

The precise contents may expand over time, but the key rule is that runtime state and launcher glue live under the project's `pony/` tree.

## Installation Responsibility

`codex-pony` should be able to detect whether the current project is already provisioned.

If the project is not provisioned:

- it should bootstrap the required `pony/` structure
- it should generate the local launcher/configuration artifacts required for the current platform
- it should then continue the requested launch flow

This makes `codex-pony` the installation boundary as well as the runtime entrypoint.

## Canonical Config

Each project should have a canonical pony config file:

- `pony/pony.system.config.yaml`

This file is the source of truth for the project's pony installation.

It should describe:

- project identity
- launcher naming
- supported launch surfaces
- any project-local defaults needed by the pony runtime

## Provisioning Markers

Platform-specific provisioning markers should indicate which launcher surfaces have been installed.

Example marker:

- `pony/pony.system.configured.windows.warp`

Future examples:

- `pony/pony.system.configured.linux.shell`
- `pony/pony.system.configured.macos.shell`
- `pony/pony.system.configured.macos.warp`

Recommended interpretation:

- `pony.system.config.yaml` describes the intended setup
- `pony.system.configured.*` files indicate completed local provisioning steps

## Launcher Strategy

The safest launcher strategy is project-specific generation.

Examples:

- `Handshake Pony Team`
- `Project A Pony Team`
- `Project B Pony Team`

Each launcher should bind to one explicit project root and use that project's `pony/` tree.

This avoids ambiguous runtime detection when multiple projects are active in parallel.

## Warp Launchers

Warp launch configurations should be generated per project at installation time.

Each generated Warp launcher should:

- carry a project-specific name
- hard-bind to the owning project root
- start in that project's working directory
- use the project's `pony/` files and coordination state

This is preferred over a single generic launcher that tries to infer project identity from Warp context at launch time.

## Shell Launchers

The system should also support launch outside Warp for Linux, macOS, and terminal-first workflows.

That means installation should also be able to generate project-local shell launchers under the project's `pony/scripts/` area.

Those launchers should:

- bind to the owning project root
- use the same project-local `pony/` structure
- avoid requiring Warp

## Optional `.zshrc` Support

Shell integration should be optional convenience only.

It must not be required for:

- project root detection
- launcher provisioning
- runtime correctness

The preferred shape is a one-line source in `.zshrc`:

```zsh
[[ -f ./pony/scripts/pony.zsh.support.zsh ]] && source ./pony/scripts/pony.zsh.support.zsh
```

That keeps the user's shell config small while letting each project provide its own pony shell helpers.

## `pony.zsh.support.zsh`

The project-local support script should be considered optional sugar.

It may provide:

- short pony identity aliases
- `WORKING_ON` helpers
- a small `codexpony` wrapper

It should not be responsible for:

- deciding the active project root
- creating runtime infrastructure silently outside the project
- acting as the primary installation mechanism

The real installation and bootstrap logic belongs in `codex-pony` and project-local provisioning scripts.

## Parallel Project Isolation

If two projects are active in parallel, they must remain isolated.

For example:

- `gitRepoA/pony/...`
- `gitRepoB/pony/...`

Launching a pony session for A must never read coordination, queue, workfile, or launcher state from B.

Project-specific launcher generation is the primary mechanism that guarantees this isolation.

## Current Direction

The standalone `agenic-pony-system` repository should be treated as reusable tooling and templates.

The active runtime structure should still be generated into each target project's `pony/` tree.

That means future implementation work should correct any prototype paths that still assume an alternate hidden state root and move them toward project-local `pony/` installation.

## Open Questions

- exact schema for `pony/pony.system.config.yaml`
- which project-local files are templates versus generated artifacts
- whether platform markers should include version information
- whether `codex-pony` should auto-install missing platform launchers or ask first
