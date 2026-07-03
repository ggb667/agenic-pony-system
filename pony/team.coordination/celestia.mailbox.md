# CELESTIA MAILBOX

Purpose: Shared governance and source-repo handoff lane for Celestia.
Contract: Not durable state by itself. Messages here request source-repo governance action or a Twilight follow-up in the shared coordination mechanism.

## Pending Items
- Twilight notice: update coordinator behavior and worker guidance to treat per-pony local `pony/work/*.md` and `pony/team.coordination/*.status.md` files as workspace artifacts in the current runtime; workers should hand durable state to Twilight through mailbox plus `/tell`, and Twilight should record it in the shared coordination mechanism.
- Twilight notice: dirty-worktree preflight is resolved in source commit `3491bb6` (`Stop default Celestia profile-file dependency`); normal coordination may proceed from the clean source-repo baseline.
- Twilight notice: when another pony must act on a worker state change, require both a mailbox notice and a direct `/tell` in the same run. Short aliases like `RD`, `AJ`, `Twi`, and `Tia` should resolve correctly, as should full display names.
- Twilight notice: normal source-repo Celestia launches should not depend on `~/.codex` profile files; if an operator explicitly uses `CODEX_PONY_PROFILE`, only the canonical manual name `celestia` is supported.
- Twilight follow-up: the source-layer runtime defects are now fixed in `agenic-pony-system`. Refresh the installed-project validation lane and confirm that installed copies no longer persist `idle` as the ready token and no longer suppress repeated pending notices after the queue clears.
- Celestia review: Handshake workspace recovery looks structurally correct. `git worktree list` now shows only Twilight at `/home/ggb66/dev/Handshake` on `pony/twi/main` plus the six worker worktrees under `pony/worktrees/*`, and `assignment.registry.tsv`, `multi.agent.control.md`, worker status files, and worker briefs are aligned with that map. Residual dirt is only untracked `.codex` files.
- Rarity instruction: when a worker is handed page-by-page data, save it into a real file immediately instead of creating a stub, summary placeholder, or partial reconstruction.

## EVH launcher title handoff - 2026-06-30
- EVH changed worker scopes for the RAG pivot: RD PDFs, AJ DB, Rarity Meds & Treatments, FS Vet Terms, Spike Docs, Twilight coordination, Pinkie idle.
- EVH static Warp launch titles live in `pony/launch.configs/EVH.pony.team.yaml`, but per-agent relaunches through `./pony/scripts/launch-team-member.sh <pony>` do not reload Warp layout tab titles.
- EVH patched `pony/scripts/launch-in-pony-shell.sh` so single-agent relaunches set terminal titles from `pony/team.coordination/assignment.registry.tsv` scope where possible.
- Please make similar shared agenic-pony-system launcher/title behavior changes so project-local agents can pick up updated worker scopes without requiring a full Warp layout relaunch, while still documenting that static Warp tab labels require a full layout restart.
