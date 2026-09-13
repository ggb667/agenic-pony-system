# Princess Celestia Sol Invictus Memory Capsule

Project: agenic-pony-system
Branch: main
Status snapshot: active
Last updated: 2026-09-13T00:00:00-04:00

Memory capsule:
- task: make startup orientation read-only and retain crash-recovery output tails across Codex-agent relaunches
- why: startup context was causing ponies to self-start work; agents also need recent terminal output after an unclean restart
- files: pony/launch.prompts/*; pony/scripts/{enter-worker-and-codex.sh,pony-session-host.py,codex-tmux-monitor.sh,output-tail.py}; docs/{runtime-loop.md,project-installation.md}; tests/test_output_tail.py
- next: validate and refresh the managed runtime into Handshake, EVH, and Codex after committing the source change
- blocker: none
- handoff: source change in progress. Direct launches use a TTY-preserving `script` relay to retain a private 1,000-line transcript; parked tmux sessions capture the last 1,000 pane lines. Startup instructions now permit read-only orientation, then require an explicit user or Twilight instruction before action.
