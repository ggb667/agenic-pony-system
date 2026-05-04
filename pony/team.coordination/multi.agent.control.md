# MULTI AGENT CONTROL

Coordinator focus for agenic-pony-system on main:
- keep the source-repo Warp launcher set dedicated to Celestia, with Twilight remaining the coordinator
- keep source-repo governance changes focused on launcher policy, prompt policy, coordinator policy, docs, and source-of-truth structure
- keep tactical project coordination pushed down to Twilight instead of absorbing it into Celestia governance work
- keep external target-project installs working, especially Handshake
- keep target-project bootstrap/install hygiene from dirtying repos by default when generating local `pony/` runtime state
- keep that no-dirty-default policy enforced from source-layer install/bootstrap behavior, including managed Git-backed ignore policy for generated target-project `pony/` trees
- implement the queue/input runtime behavior from `docs/runtime-loop.md`
- keep shell launch startup robust by invoking `start-session.sh` directly rather than typing a synthesized command into the interactive buffer
- treat `pony/work/*.md` as the canonical home for worker-local task state; coordinator status files and mailboxes should summarize deltas or route requests instead of duplicating full state
- allow concise letters to Princess Celestia through `pony/team.coordination/celestia.mailbox.md` for source-repo governance or shared-system requests, while leaving day-to-day coordination with Twilight
