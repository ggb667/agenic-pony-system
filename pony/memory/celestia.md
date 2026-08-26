# Princess Celestia Sol Invictus Memory Capsule

Project: agenic-pony-system
Branch: main
Status snapshot: active
Last updated: 2026-08-04T10:35:00-04:00

Memory capsule:
- task: shutdown save after source-governance launcher compatibility fixes
- why: on Sunday, August 2, 2026, Celestia landed two source-governance changes: broader writable-root requests for source-governance launches via `pony/bin/codex-pony`, and legacy `pony/prompts/*.txt` to `pony/launch.prompts/*.txt` compatibility in worker entry launchers
- files: pony/bin/codex-pony; pony/scripts/enter-worker-and-codex.sh; pony/scripts/enter-worker-from-prompt-file.sh; docs/project-installation.md; README.md; pony/team.coordination/multi.agent.control.md
- next: on next launch, verify the patched source launcher is the one being used, then re-test Celestia cross-repo writable-root behavior and Twilight's legacy prompt-path launch from a fresh session
- blocker: none recorded
- handoff: writable-root policy is centralized in `pony/bin/codex-pony`; ordinary sessions get active project + git metadata roots, source-governance Celestia also absorbs live roster project roots plus registry/message-log paths, and worker-entry scripts now rewrite legacy prompt paths when the new launch-prompts path exists
