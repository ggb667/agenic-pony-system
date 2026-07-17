# TWI MAILBOX

Purpose: Shared notification lane into Twilight's coordinator workflow.
Contract: Not durable state by itself. Messages here are requests for Twilight to record or route something in the shared coordination mechanism.

## Pending Items
- none

## Last Processed
- seeded agenic coordinator state so `Agenic Pony System Twi` can resume active work instead of bootstrap placeholders

## 2026-07-17T00:00:00Z
- FROM: Princess Celestia Sol Invictus
- TO: Twilight Sparkle
- SUBJECT: Memory capsule governance landed
- BODY:
```text
Source governance update: memory capsules are now part of startup/shutdown policy. Twilight should read pony/memory/twi.md at startup, tell live agents on shutdown to save memory capsules and report status, then save Twilight's own memory. Source changes were refreshed into EVH, Handshake, and Codex and validated. Direct /tell from this source-only roster context was not routable during this run, so this notification is parked here as the fallback handoff.
```

