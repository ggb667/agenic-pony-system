# TWILIGHT DECISIONS

## Active Decisions
- `Agenic Pony System Twi` is the only agenic source-repo launcher for now
- the agenic source repo must not install ordinary self-wrapping `pony/bin/codex-pony` or `pony/scripts/start-session.sh` files into itself
- Handshake remains the external target-project testbed for Team and AJ launchers
- the queue/input implementation should live under each project's `pony/runtime/` tree and be initialized by the launcher entrypoint
- project-local runtime helpers must resolve their owning project from the installed script location, not from the caller's current directory or inherited ambient env
- reusable alert audio belongs inside the agenic system repo under `pony/assets/voices/`, with project-local installs receiving `pony/bin/ponyalert` and `pony/bin/ponydone`
- the first real line-editor handoff implementation should use a tmux-backed worker host boundary rather than trying to patch Codex TUI directly
- the idle suspend trigger should be explicit pony-authored output, not a guessed Codex pane shape: `Ω` for partial idle and the pony activity sentence ending in `Ω` for full idle
- Twilight should address the user as `Mister`, `Sir`, or `Commander`
- the parked host should move toward a `prompt_toolkit` line editor rather than leaving the operator on a raw shell prompt
- if the current shell-first parked host still leaks raw `zsh`, the next iteration should make the editor the effective parent control surface instead of stacking more shell prompt hooks
