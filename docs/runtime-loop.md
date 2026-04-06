# Runtime Loop Design

This document defines the initial runtime model for the standalone Agenic Pony System.

## Core Loop

The runtime is queue-driven:

`idle -> running.prompt or running.agent.prompt -> idle`

There is no separate wake/sleep model for ponies. The line-editor host watches the queue and starts the next item when the system is idle.

## States

### `idle`

The system is not actively executing a prompt.

Responsibilities:

- watch the queue
- preserve the user's unsent draft buffer
- accept direct user submission
- surface pending agent-originated requests to the user

### `running.prompt`

The system is executing a prompt submitted directly by the user.

### `running.agent.prompt`

The system is executing a prompt enqueued by a Codex agent, including Twilight or any worker.

This includes:

- coordinator follow-up work
- worker-to-worker requests
- worker-to-Twilight requests
- agent-originated approval or escalation requests
- any other queued prompt created by an agent

At the runtime layer, Twilight is not special. All Codex agents use the same agent-prompt mechanism.

## Queue Model

The queue is FIFO.

Each queue item has:

- `source`: `user` or `agent`
- `requester_identity`: optional display metadata for agent-originated items
- `body`: the submitted prompt text
- `created_at`

## Queue Arbitration

When the system returns to `idle`:

- if there is a submitted user prompt ready to run, it wins over pending agent prompts
- otherwise, the next queued item runs in FIFO order

This does not hide pending agent work. The user must be shown that pending work exists before they decide what to do next.

## Pending Agent Request Notice

If an agent-originated queue item arrives while the system is running, or while the user is sitting in `idle`, the user should be informed of the pending request.

Preferred rendering:

- show the requester's pony symbol, color, and display name when available
- show the actual request body plainly

Example:

```text
While we were working I received a request from Twilight Sparkle:
✶ Applejack, please clean up the files and folders and make sure you are on the xyz branch and pull the latest from main into that branch.
```

If the system is idle when the agent prompt is about to run, it should show the prompt directly rather than wrapping it in a "while we were working" notice.

Examples:

```text
Twilight Sparkle asked:
✶ Applejack, please clean up the files and folders and make sure you are on the xyz branch and pull the latest from main into that branch.
```

```text
Rainbow Dash requested:
⚡ Twilight, please verify whether the branch assignment changed before I continue.
```

Purpose:

- preserve transparency
- let the user decide whether to continue, interrupt, or redirect
- avoid silent prioritization of agent work over user intent

## Stopping Point Rule

A stopping point is any point at which an agent is not actively asking for required data.

This means a run should stop even if more work exists, as long as the current run is not blocked on required input.

A prompt is at a stopping point when:

- it has completed a work slice
- it is offering a next step
- it is waiting for direction such as `continue`
- it has no required question pending

Examples that are stopping points:

- "If you want, Commander, I can draft the concrete state machine and message schema next in the new repo."
- any similar handoff where more work could continue, but no required data is being requested

Examples that are not stopping points:

- approval requests
- escalation requests
- required clarification questions
- any other request where the run is waiting on necessary user input

## Draft Preservation

While in `idle`, the user may have a partially typed draft in the line editor.

That draft must survive:

- arrival of queued agent prompts
- notices about pending agent work
- queue-driven runs that start after other submitted input

Requirements:

- the draft text must be restorable unchanged
- if the editor supports it, cursor and edit state should also be restored
- queued notices must not destroy, overwrite, or silently submit the user's draft

Empty input is not a special case because no submission occurs until Enter is pressed.

Cancelled input is simply cancelled input.

## Agent-Originated Input Tasks

The input envelope is not a separate protocol. It is a TUI task.

When invoked by an agent:

- the request is represented as an agent-originated queue item
- when executed, it runs as `running.agent.prompt`
- the result is written back to the calling agent

The result path must remain transparent to the user:

- the user should be able to see what the agent asked for
- the user should be able to understand what their answer applies to

This matters especially for:

- approvals
- escalation requests
- explicit choices

## Run Serialization

Only one prompt executes at a time.

Rules:

- no nested prompt execution
- prompts enqueued during a run are deferred until the next `idle`
- user-submitted prompts take precedence at `idle`
- otherwise queued items run FIFO

## Twilight Dispatch Semantics

Twilight sends messages to workers whenever she receives new instructions.

Those messages are not executed immediately by "waking" workers. Instead:

- Twilight enqueues the resulting agent prompt(s)
- any other agent may also enqueue agent prompt(s), including requests directed back to Twilight
- the line-editor host continues watching the queue
- the next queued item starts when the system is idle

This keeps the runtime simple:

- one active run
- one queue
- explicit pending notices
- no hidden background execution model

## Open Questions

- exact queue item storage format on disk or in memory
- whether agent notices should collapse repeated requests from the same sender
- whether the user can explicitly promote a pending agent item to run next
- exact TUI rendering for requester color and symbol metadata
