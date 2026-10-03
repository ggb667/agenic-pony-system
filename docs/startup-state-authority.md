# Startup State Authority

## Problem

Startup currently asks an agent to read several independently writable surfaces
that all resemble current state:

- `pony/memory/<agent>.md`
- `pony/work/<agent>.md`
- `pony/team.coordination/<agent>.status.md`
- `pony/team.coordination/assignment.registry.tsv` (`scope`)
- Twilight TODO, review, approval, and event-history files
- the private rolling terminal transcript

This produces reports such as “A says X, B says Y, and C may say Z.” The agent is
correctly noticing disagreement, but the system should not create several peers
that each claim to be current.

## Concrete Findings

1. Memory capsules contain current-looking task, status, next-step, blocker, and
   handoff fields.
2. Workfiles contain another status/scope pair plus a restart capsule with task,
   next-step, and blocker fields.
3. Status files contain a third status, blocker, and next-step representation.
4. Assignment registry `scope` is preserved across refresh and is frequently
   used as another task/status summary.
5. Twilight TODO and approval files are regenerated from status files, while
   event history may retain older sections named “Current State.”
6. Worker preflight mutates status-file branch, worktree, and push state. For a
   dirty coordinator worktree it also replaces semantic status, blocker, and
   next step, mixing workspace observation with task authority.
7. Managed refresh previously reset existing workfile permissions, restart
   capsules, and status approvals to `none recorded`. Refresh also changed file
   modification times, so a newest-`mtime` rule would have selected newly erased
   state as truth.
8. The private 1,000-line terminal transcript is recorded in direct and hosted
   launch paths, but ordinary orientation does not consult it. It should be read
   after a crash or an explicit request to recover/check recent state, while
   remaining non-authoritative.

## Canonical Current State

Each agent should have exactly one canonical machine-readable current-state
record, for example:

`pony/team.coordination/agent-state/<slug>.json`

The exact path and schema should be finalized with Twilight before migration,
but it should contain at least:

```json
{
  "schemaVersion": 1,
  "agentId": "RAINBOW_DASH",
  "revision": 42,
  "updatedAt": "2026-10-03T16:00:00Z",
  "updatedBy": "TWILIGHT_SPARKLE",
  "assignment": {
    "task": "...",
    "status": "...",
    "next": "...",
    "blocker": null,
    "approvals": []
  },
  "workspaceObservation": {
    "branch": "pony/rd/main",
    "worktree": "/path/to/worktree",
    "pushStatus": "clean_and_pushed",
    "observedAt": "2026-10-03T15:59:50Z"
  }
}
```

Task authority and workspace observation are separate subrecords so preflight
cannot replace an assignment merely because Git is dirty.

## Role Of Timestamps

Timestamps help detect stale projections but must not choose authority by
themselves.

- The canonical record carries `revision`, `updatedAt`, and `updatedBy`.
- Writers perform compare-and-swap against `revision` and increment it
  atomically.
- Generated views carry `sourceRevision` and `generatedAt`.
- A view whose `sourceRevision` differs is stale and may be regenerated.
- Filesystem `mtime` is diagnostic only. Installation, copying, checkout, and
  formatting can alter it without producing newer semantic state.

## Eliminate Redundant Current State

- **Assignment registry:** retain identity, branch/worktree routing, workfile,
  and prompt paths; remove mutable task/status meaning from `scope`.
- **Status Markdown:** generate it from canonical state for human inspection,
  or retire it after consumers migrate. Do not edit it independently.
- **Workfile:** keep scratch notes and implementation detail; remove the live
  status and restart capsule once canonical state is established.
- **Memory capsule:** keep durable narrative/history and lessons, not a second
  live task/status record. Read it only when historical context is needed.
- **Twilight TODO/review/approval views:** derive them from canonical records
  and stamp them with source revisions.
- **Event history:** append-only history; never label an old block as current.
- **Terminal transcript:** crash/conversation recovery only; never task
  authority.

## Startup Contract

1. Read the one canonical current-state record.
2. If the prior session crashed or the user explicitly asks to check/recover
   recent state, read the private transcript tail next.
3. Consult work notes or memory history only when needed for the assigned task.
4. Never reconcile several peer “current” narratives.
5. If the canonical record is missing, malformed, or has a failed revision
   update, preserve all evidence, report the exact defect to Twilight, and park;
   do not crash or overwrite another source.

## Migration Plan

1. Stop destructive installer normalization of existing permissions, capsules,
   and approvals; add regression coverage.
2. Define and validate the canonical JSON schema and atomic update utility.
3. Have Twilight select the current truth once per agent and write revision 1.
4. Change preflight/postflight to update only `workspaceObservation`.
5. Generate status/TODO/approval views from canonical revisions.
6. Remove live-state fields from workfiles, memory capsules, and registry scope.
7. Change startup orientation to read canonical state first and recent transcript
   only for crash or explicit recovery.
8. Retire legacy current-state readers after a compatibility window.

Launching every pony is neither required nor desirable for this migration.
