# Princess Celestia Sol Invictus Memory Capsule

Project: agenic-pony-system
Branch: main
Status snapshot: active
Last updated: 2026-09-14T02:45:00-04:00

Memory capsule:
- task: establish durable versus ephemeral `/tell` semantics for offline inter-project delivery
- why: the Codex TUI does append to a configured offline recipient inbox, but current messages expire after one hour and unread messages coalesce by sender—incorrect for governance/enhancement requests
- files: pony/team.coordination/{multi.agent.control.md,source.runtime.summary.md}; docs/runtime-loop.md; pony/memory/celestia.md
- next: await Codex Pinkie's implementation report through Codex Twilight, then review the TUI contract and align source validation/documentation
- blocker: none; Codex Twilight received the exact protocol request and is coordinating Pinkie's implementation
- handoff: source policy records that configured `messageLogPath` delivery works while the recipient is offline, but only for ephemeral traffic. Codex Twilight received the required durable IPC contract in message `8c8da1e6-e61d-4af2-84ec-86a70f35084f`: delivery class, non-expiry/non-coalescing, persistent receipt ledger, and configured cross-project endpoint requirements.
- 2026-09-14 governance decision: before explicit task execution, every clean `main` worktree must run `git fetch --prune origin` then `git pull --ff-only`; dirty/non-main/non-fast-forward state is recorded for Twilight rather than auto-pulled. Existing linked worker worktrees are not fresh assignment starts—Twilight must confirm refreshed `main` and explicitly prepare them without rewriting dirty worker state.
- 2026-09-14 restart handoff: Twilight delivered three correctly routed messages to `pony/runtime/pony.chat.jsonl`; the durable rollout handoff is entry `e87d8f89-70ca-4e07-ab6f-1508fdd08d4d`. Pinkie IPC changes are in Codex commit `a8b48089ac`; the shared `codex-tui` rebuild is complete. This Celestia process started before that rebuild and did not surface the queued lane automatically. User authorized a restart after state was saved.
- 2026-09-15 EVH launcher incident: an interrupted managed refresh left `pony/runtime/install-project.state=failed` and an empty `install-project.lock/`; all subsequent launches waited indefinitely before Codex. Recovery removed the stale lock and restored EVH to `complete`. Source now reclaims ownerless locks and locks owned by dead local PIDs (never another host); source files are dirty alongside pre-existing coordination changes, and the focused lock-policy tests pass.
- 2026-09-22 active governance item: custom/source Codex builds must retain upstream-version detection but replace the unsafe global npm upgrade instruction with custom-source update-and-rebuild guidance. Upgrade 0.154.0 -> 0.155.1 is not authorized yet. AJ's original `agent_ipc`-refactor exit remains unproven: session records end after a normal task completion, with no panic/core/OOM/journal evidence and no preserved launcher exit status or stderr; later manual-resume permission failures are secondary.
