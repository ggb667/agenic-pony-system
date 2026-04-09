# TWILIGHT TODO

Generated: 2026-04-09 active coordinator state

## Immediate
- relaunch fresh Handshake Twi/AJ tabs on Handshake `main` and verify whether the new immediate editor-loop startup path takes over before any raw shell prompt appears
- confirm the parked host now drops into the prompt_toolkit line editor rather than raw shell command entry
- if raw `zsh` still appears, replace the shell-first parked-host path with an editor-first parent control loop instead of layering more prompt hooks onto `zsh`
- improve parked-session scrollback so it behaves like Codex line-by-line history instead of a jumping tmux or shell transcript
- keep Handshake Twi under strict runtime observation so she does not mutate Handshake coordination state or git ignore state during the runtime test lane
- keep the agenic source repo launcher set limited to Twi while the source-repo special case is in effect
- keep Handshake launcher installs functioning as the installed validation target for agenic runtime behavior
- keep mirrored Twi prompts, workfiles, and backlog notes aligned between `agenic-pony-system` and `Handshake/pony` when those text surfaces intentionally mirror each other

## Next
- continue the queue-driven runtime loop from `docs/runtime-loop.md` beyond the new filesystem/runtime scaffold
- tighten or replace the sentinel-triggered suspend path only if the fresh Handshake sessions still show false positives or misses
- replace any remaining raw-shell parked-host behavior that leaks shell commands like `ls` or natural-language prompts instead of routing through the editor host
- remove or mark any remaining stale Handshake archive docs that still present `handshake-shared` or deleted sibling worktrees as live guidance
- commit and push the latest agenic repairs after validation
