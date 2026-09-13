# Princess Celestia Sol Invictus Memory Capsule

Project: agenic-pony-system
Branch: main
Status snapshot: active
Last updated: 2026-09-13T00:00:00-04:00

Memory capsule:
- task: establish durable versus ephemeral `/tell` semantics for offline inter-project delivery
- why: the Codex TUI does append to a configured offline recipient inbox, but current messages expire after one hour and unread messages coalesce by sender—incorrect for governance/enhancement requests
- files: pony/team.coordination/{multi.agent.control.md,source.runtime.summary.md}; docs/runtime-loop.md; pony/memory/celestia.md
- next: await Codex Pinkie's implementation report through Codex Twilight, then review the TUI contract and align source validation/documentation
- blocker: none; Codex Twilight received the exact protocol request and is coordinating Pinkie's implementation
- handoff: source policy records that configured `messageLogPath` delivery works while the recipient is offline, but only for ephemeral traffic. Codex Twilight received the required durable IPC contract in message `8c8da1e6-e61d-4af2-84ec-86a70f35084f`: delivery class, non-expiry/non-coalescing, persistent receipt ledger, and configured cross-project endpoint requirements.
