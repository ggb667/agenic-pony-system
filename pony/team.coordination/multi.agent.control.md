# MULTI AGENT CONTROL

Coordinator focus for agenic-pony-system on main:
- keep the source-repo Warp launcher set dedicated to Celestia, with Twilight remaining the coordinator
- keep the source-repo Celestia launcher independent from `~/.codex/*.config.toml` files during normal startup, while treating `celestia` as the canonical manual profile name if an operator explicitly uses a Codex profile
- keep source-repo governance changes focused on launcher policy, prompt policy, coordinator policy, docs, and source-of-truth structure
- keep tactical project coordination pushed down to Twilight instead of absorbing it into Celestia governance work
- keep external target-project installs working, especially Handshake
- keep target-project bootstrap/install hygiene from dirtying repos by default when generating local `pony/` runtime state
- keep that no-dirty-default policy enforced from source-layer install/bootstrap behavior, including managed Git-backed ignore policy for generated target-project `pony/` trees
- keep MCP and other Codex session credentials flowing through explicit launcher env files instead of relying on incidental shell startup state
- keep worker launch sandboxes able to write the authoritative project-root `pony/team.coordination/*` and `pony/work/*` files even when the active worker session runs from `pony/worktrees/<slug>/`
- require workers to publish a concise mailbox notice to Twilight in the same run when a coordination-relevant state change occurs, and when another pony must act, require a direct `/tell` in that same run; short aliases and full display names should both resolve through the active worker identity map
- treat mailbox files as notification lanes rather than reboot-state storage; if a fact must survive restart, require it to be written into the authoritative `pony/work/*.md` and `pony/team.coordination/*.status.md` files, or escalated to Twilight as an exact write request when the worker cannot reach those files
- require blockers caused by missing connection strings, secrets, endpoints, approvals, or other external prerequisites to name the exact missing artifact, the expected owner, and the next unblock step in canonical worker state before idle
- implement the queue/input runtime behavior from `docs/runtime-loop.md`
- keep shell launch startup robust by invoking `start-session.sh` directly rather than typing a synthesized command into the interactive buffer
- treat `pony/work/*.md` as the canonical home for worker-local task state; coordinator status files and mailboxes should summarize deltas or route requests instead of duplicating full state
- allow concise letters to Princess Celestia through `pony/team.coordination/celestia.mailbox.md` for source-repo governance or shared-system requests, while leaving day-to-day coordination with Twilight
