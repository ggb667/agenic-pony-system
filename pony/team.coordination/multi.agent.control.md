# MULTI AGENT CONTROL

Purpose: Source-repo governance summary for how the pony runtime should divide responsibility.
Contract: Shared policy document. It defines the intended coordination model and boundaries, but Twilight still owns live operational state and routing.

Coordinator focus for agenic-pony-system on main:
- keep the source-repo Warp launcher set dedicated to Celestia, with Twilight remaining the coordinator
- keep the source-repo Celestia launcher independent from `~/.codex/*.config.toml` files during normal startup, while treating `celestia` as the canonical manual profile name if an operator explicitly uses a Codex profile
- keep source-repo governance changes focused on launcher policy, prompt policy, coordinator policy, docs, and source-of-truth structure
- keep tactical project coordination pushed down to Twilight instead of absorbing it into Celestia governance work
- keep external target-project installs working, especially Handshake
- keep target-project bootstrap/install hygiene from dirtying repos by default when generating local `pony/` runtime state
- keep that no-dirty-default policy enforced from source-layer install/bootstrap behavior, including managed Git-backed ignore policy for generated target-project `pony/` trees
- keep MCP and other Codex session credentials flowing through explicit launcher env files instead of relying on incidental shell startup state
- keep the runtime aligned with the current shared-state rule: workers report changes to Twilight, and Twilight maintains the authoritative coordination state rather than relying on worker-local file writes
- require workers to send the needed direct `/tell` messages in the same run when a coordination-relevant state change occurs; short aliases and full display names should both resolve through the active worker identity map
- keep `/tell` routing team-local by default for ambiguous targets so same-named ponies in different live teams cannot receive one another's traffic by accident
- allow explicit cross-repo `/tell` delivery only when the target is disambiguated through the active generated agent roster, such as `<project>:Twilight Sparkle`; preserve `Princess Celestia Sol Invictus` as the unique global source-governance identity
- keep the generated `CODEX_AGENT_CONFIG` roster contract explicit: include `messageLogPath`, `registryPath`, qualified aliases, the local project roster, and any live cross-project targets visible on the active bus; shell helpers should invoke `agent-config.py` via `python3` when the file exists instead of relying on its executable bit
- treat simple pony-to-pony `/tell` pings, acknowledgements, and short live notes as conversational IPC by default: reply live with `/tell` unless the message also carries a durable state change, blocker, or explicit write request
- treat mailbox files as notification lanes rather than reboot-state storage; if a fact must survive restart, require Twilight to record it in the shared authoritative coordination mechanism from an exact worker write request
- keep pending user approvals isolated from routine mailbox acknowledgements and generated helper review text; unresolved approvals belong in a dedicated coordinator approval lane until the user answers
- keep generated `Twilight review needed`-style snippets out of durable coordinator history; they belong in a review queue or todo surface, not in canonical event history
- require blockers caused by missing connection strings, secrets, endpoints, approvals, or other external prerequisites to name the exact missing artifact, the expected owner, and the next unblock step in canonical worker state before idle
- require every worker stopping point to leave behind a concise restart capsule in the assigned workfile, and when that capsule implies shared durable coordination changes, require the matching exact `/tell` update to Twilight in the same run
- implement the queue/input runtime behavior from `docs/runtime-loop.md`
- keep shell launch startup robust by invoking `start-session.sh` directly rather than typing a synthesized command into the interactive buffer
- prefer lightweight parked hosts over disposable direct Codex launches so tmux scrollback, editor history, and restart continuity survive ordinary relaunches for more than just Celestia
- do not treat per-worker local `pony/work/*.md` or `pony/team.coordination/*.status.md` files as shared authority in the current runtime; they are workspace artifacts unless Twilight is explicitly assigned to maintain them
- allow concise letters to Princess Celestia through `pony/team.coordination/celestia.mailbox.md` for source-repo governance or shared-system requests, while leaving day-to-day coordination with Twilight
