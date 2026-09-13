# Princess Celestia Sol Invictus Memory Capsule

Project: agenic-pony-system
Branch: main
Status snapshot: active
Last updated: 2026-09-13T00:00:00-04:00

Memory capsule:
- task: establish durable versus ephemeral `/tell` semantics for offline inter-project delivery
- why: the Codex TUI does append to a configured offline recipient inbox, but current messages expire after one hour and unread messages coalesce by sender—incorrect for governance/enhancement requests
- files: pony/team.coordination/{multi.agent.control.md,source.runtime.summary.md}; docs/runtime-loop.md; pony/memory/celestia.md
- next: route a Codex TUI IPC change defining a durable delivery class with acknowledgement-based retention; source-side docs/policy must then adopt the class
- blocker: the source launcher cannot create true durable `/tell` semantics alone because the existing TUI storage/read/cleanup implementation owns expiry and coalescing
- handoff: source policy now records that configured `messageLogPath` delivery works while the recipient is offline, but only for ephemeral traffic. Do not rely on it for durable governance or enhancement handoff until the TUI protocol changes.
