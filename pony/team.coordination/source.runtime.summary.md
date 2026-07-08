# SOURCE RUNTIME SUMMARY

Purpose: Compact source-repo launch summary for Celestia and Twilight.
Contract: Distills the stable source-repo rules from `README.md`, `docs/runtime-loop.md`, and `docs/project-installation.md` so source-governance launches do not need to reread those broader docs every time.

## Source Repo Special Case

- `agenic-pony-system` is the reusable source of truth for launcher behavior, prompts, install logic, and design docs
- the live runtime for ordinary project work belongs inside each target project's local `pony/` tree
- the source repo is a special case: Celestia governs source-repo policy, Twilight remains the coordinator, and worker-launch validation belongs in installed target-project runtimes such as `/home/ggb66/dev/codex/pony`

## Repo Boundary

- source-repo governance work stays in `/home/ggb66/dev/agenic-pony-system`
- installed target-project runtime churn belongs in the target project unless the user explicitly assigns cross-repo governance work
- bootstrap hops through source-layer scripts are expected managed plumbing, not a policy conflict, as long as control returns to the active project's local pony state before work begins

## Shared Coordination Model

- Twilight maintains the shared authoritative coordination mechanism
- worker-local `pony/work/*.md` and `pony/team.coordination/*.status.md` files are workspace artifacts unless Twilight is explicitly assigned to maintain them
- when a worker causes a durable shared-state change, the worker should tell Twilight the exact update to record in the same run
- simple live `/tell` pings, acknowledgements, and short coordination notes stay in the live IPC lane by default and should normally receive a short direct `/tell` reply rather than mailbox or history churn
- if a blocker depends on a missing secret, endpoint, approval, or similar prerequisite, the shared coordination state must name the exact missing artifact, expected owner, and next unblock step

## Install And Validation Boundaries

- source changes land in `agenic-pony-system`
- installed copies under `<project-root>/pony/` should be refreshed when managed prompts, scripts, or runtime files change
- runtime validation should happen from the installed target project's `pony/` tree
- `codex-rs` edits are reserved for Codex UI behavior, not general pony policy
