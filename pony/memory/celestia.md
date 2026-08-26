# Princess Celestia Sol Invictus Memory Capsule

Project: agenic-pony-system
Branch: main
Status snapshot: active
Last updated: 2026-08-26T08:05:00-04:00

Memory capsule:
- task: harden startup prompt-compliance guidance and propagate it into installed runtimes
- why: on Wednesday, August 26, 2026, Twilight reported a shared startup-compliance risk from EVH worker testing; source guidance now makes concrete Current condition handoffs continue immediately into memory/workfile/state initialization, and user-pointed non-file-changing mistakes must be corrected without asking permission
- files: pony/launch.prompts/{aj,fs,pinkie,rarity,rd,spike,twi}.txt; pony/scripts/{enter-worker-and-codex.sh,pony-session-host.py,start-session.sh}; docs/{project-installation.md,runtime-loop.md}; pony/team.coordination/{multi.agent.control.md,source.runtime.summary.md}
- next: verify actual worker launches in EVH, Handshake, and Codex display and obey the hardened startup guidance
- blocker: none recorded
- handoff: installed target runtimes for `/home/ggb66/dev/EVH`, `/home/ggb66/dev/Handshake`, and `/home/ggb66/dev/codex` were refreshed from source via `scripts/install-project.sh` in the same run as the source guidance update
