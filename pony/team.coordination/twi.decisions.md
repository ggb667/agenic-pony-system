# TWILIGHT DECISIONS

Purpose: Twilight's curated record of durable coordinator decisions for this source repo.
Contract: Shared coordinator artifact maintained by Twilight. Use it for settled policy, not ephemeral worker scratch state.

## Active Decisions
- `Agenic Pony System Celestia` is the dedicated agenic source-repo Warp launcher; the agenic Twi Warp launcher is retired
- the agenic source repo must not install ordinary self-wrapping `pony/bin/codex-pony` or `pony/scripts/start-session.sh` files into itself
- Handshake remains the external target-project testbed for Team and AJ launchers
- the queue/input implementation should live under each project's `pony/runtime/` tree and be initialized by the launcher entrypoint
- in the current runtime, per-worker local `pony/work/*.md` and `pony/team.coordination/*.status.md` files are workspace artifacts rather than shared authority; durable team state must route through Twilight's shared coordination mechanism
- project-local runtime helpers must resolve their owning project from the installed script location, not from the caller's current directory or inherited ambient env
- reusable alert audio belongs inside the agenic system repo under `pony/assets/voices/`, with project-local installs receiving `pony/bin/ponyalert` and `pony/bin/ponydone`
- the first real line-editor handoff implementation should use a tmux-backed worker host boundary rather than trying to patch Codex TUI directly
- the idle suspend trigger should be explicit pony-authored output, not a guessed Codex pane shape: `Ω` for partial idle and the pony activity sentence ending in `Ω` for full idle
- Twilight should address the user as `Mister`, `Sir`, or `Commander`
- the parked host should move toward a `prompt_toolkit` line editor rather than leaving the operator on a raw shell prompt
- if the current shell-first parked host still leaks raw `zsh`, the next iteration should make the editor the effective parent control surface instead of stacking more shell prompt hooks
- worker continuity is a first-class runtime requirement: ordinary relaunch must preserve local draft/history state, and each worker stopping point should refresh a concise restart capsule in the assigned workfile plus any exact Twilight delta needed for shared durable state
- when present, per-worker memory capsules should be read at startup and refreshed on shutdown or other material restart-context changes
- on shutdown, Twilight should tell live agents to save memory and report status before Twilight saves her own memory capsule
- lightweight parked-host behavior should extend beyond Celestia so Twilight and ordinary workers preserve tmux scrollback and restart continuity instead of relying on disposable foreground Codex launches
- pending user approvals should remain isolated from routine mailbox acknowledgements in a dedicated coordinator lane until explicitly answered by the user
- generated `Twilight review needed` snippets should not be appended to durable coordinator history; they belong in generated review-queue surfaces only
- possible later enhancement: for `READY_KEEP_LIVE` ponies, keep a lightweight local parked host awake while Codex sleeps, and wake Codex automatically on real inbound work such as direct user input, unread `/tell` delivery, or another runtime notice explicitly marked as requiring model work; the pony-style startup identity banner should be host-rendered locally, while the model-only startup self-brief should run only after that wake event
- pony behavior and horseshow runtime rules must remain always-on even when reusable coordination instructions are disabled for a run
- reusable launch-prompt coordination instructions should be optional at startup and disableable via `AGENIC_PONY_DISABLE_REUSABLE_PROMPT=1` without removing pony voice, alerting, or idle behavior
- project installs should self-refresh managed pony launchers, scripts, and reusable prompt templates on rerun so repo-local startup behavior can heal stale installs
- shell launchers should run the first `start-session.sh` handoff directly from shell init instead of injecting a quoted command into `BUFFER`
- shell launchers should source an explicit launch env file before starting Codex so MCP credentials such as `GITHUB_PAT_TOKEN` do not depend on ambient shell startup state
- unqualified `Celestia` already implies the `agenic-pony-system` source-repo governance lane; Twilight should judge those messages by concrete operational purpose, not by whether the sender redundantly restated repo or governance scope
- if a Twilight delivery test resolves to the correct agenic Celestia `messageLogPath` but append fails under sandbox policy, classify it as a permission-only blocker rather than a routing failure
