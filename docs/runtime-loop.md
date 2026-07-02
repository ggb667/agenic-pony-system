# Runtime Loop Design

This document defines the initial runtime model for the standalone Agenic Pony System.

## Core Loop

The runtime is queue-driven:

`ready -> running.prompt or running.agent.prompt -> ready`

There is no separate wake/sleep or suspend model for ponies. The line-editor host watches the queue and starts the next item when the system is ready, but it must not stop or suspend Codex on the user's behalf.

## States

### `ready`

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

At the queue and runtime layer, agent-originated prompts follow the same envelope and scheduling rules. Twilight is still a source-repo special case in `agenic-pony-system`: only the Twilight launcher should be treated as live in the agenic source repo, while worker-launch validation happens in installed project-local runtimes such as `Handshake/pony`.

## Direct Pony IPC

There is also a separate direct pony-to-pony lane in the Codex fork TUI through
the built-in `/pony` slash command.

Examples:

- `/tell rd do a ls -la`
- `/tell Rainbow Dash do a ls -la`
- `/tell twi please verify the branch before I continue`
- `/tell all status check`

Current behavior:

- sending is handled directly by the Codex TUI rather than by `queue-runtime.sh`
- receiving is polled from the Codex-side local IPC log, mirrored into the
  project-local `pony/runtime` queue, and then injected into the target pony
  session as a synthetic prompt when the live composer can accept it
- successful `/pony` dispatch clears the command from the TUI composer

Addressing rule:

- the runtime should accept both the worker display name and short aliases such as `rd`, `aj`, `twi`, and `tia`
- alias resolution should canonicalize through the same worker identity map used by launchers and coordination state

Current limitation:

- this direct IPC path is still not a pure queue-native transport; it uses the
  queue as a persistence bridge for the live TUI path
- immediate live delivery removes the queued item again after successful
  injection
- sender-side `/tell` state and receiver-side queue state still depend on the
  Codex fork and the installed `queue-runtime.sh` remaining aligned

So the system currently has two message lanes:

- queue-backed project-local runtime messages for the line-editor host
- direct Codex-to-Codex `/tell` IPC for live pony sessions

They are related, but they are not yet unified.

## Queue Model

The queue is FIFO.

Each queue item has:

- `source`: `user` or `agent`
- `requester_identity`: optional display metadata for agent-originated items
- `body`: the submitted prompt text
- `created_at`

## Queue Arbitration

When the system returns to `ready`:

- if there is a submitted user prompt ready to run, it wins over pending agent prompts
- otherwise, the next queued item runs in FIFO order

This does not hide pending agent work. The user must be shown that pending work exists before they decide what to do next.

## Pending Agent Request Notice

If an agent-originated queue item arrives while the system is running, or while the user is sitting in `ready`, the user should be informed of the pending request.

Preferred rendering:

- show the requester's pony symbol, color, and display name when available
- show the actual request body plainly

Example:

```text
While we were working I received a request from Twilight Sparkle:
✶ Applejack, please clean up the files and folders and make sure you are on the xyz branch and pull the latest from main into that branch.
```

If the system is ready when the agent prompt is about to run, it should show the prompt directly rather than wrapping it in a "while we were working" notice.

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
- it has already persisted any task-relevant state that the next launch will need, such as workfile status, coordinator status, blockers, or next-step notes

Examples that are stopping points:

- "If you want, Commander, I can draft the concrete state machine and message schema next in the new repo."
- any similar handoff where more work could continue, but no required data is being requested

Special worker-launch exception:

- when a non-coordinator worker has just launched, reads local state, and finds `blank`, `WAITING`, or `unassigned`, it should report that status but remain live at the Codex prompt for immediate follow-up input rather than emitting an idle sentinel and parking itself
- when a non-coordinator worker is in that blank or waiting state, it should not scan the repository looking for self-assigned work; it should wait for a concrete assignment
- if the user grants a permission, approval, recurring exception, or standing instruction, the worker should persist that approval into the local workfile and status file during the same run so the next launch does not ask again unless the approval is revoked

Examples that are not stopping points:

- approval requests
- escalation requests
- required clarification questions
- any other request where the run is waiting on necessary user input

## Idle Sentinel

At a stopping point, the active pony should end its response with one exact idle marker and nothing after it.

Examples:

- Partial idle:
  `Ω`
- Full idle:
  `Twilight Sparkle is reading a book and awaiting new instructions. Ω`
  `Twilight Sparkle is practicing her magic and awaiting new instructions. Ω`
  `Applejack is bucking apples and awaiting new instructions. Ω`
  `Pinkie Pie is planning a party and awaiting new instructions. Ω`
  `Rarity is refining a sketch and awaiting new instructions. Ω`
  `Spike is sorting scrolls and awaiting new instructions. Ω`
  `Fluttershy is feeding her animals and awaiting new instructions. Ω`
  `Fluttershy is wrestling a bear and awaiting new instructions. Ω`
  `Rainbow Dash is practicing new tricks and awaiting new instructions. Ω`
  `Rainbow Dash is napping on a cloud and awaiting new instructions. Ω`
  `Princess Celestia is tending the sun and awaiting new instructions. Ω`
  `Princess Celestia is attending court and awaiting new instructions. Ω`

Rules:

- idle markers are advisory handoff markers only; they must not be used to suspend or stop Codex automatically
- `Ω` by itself means partial idle: safe stopping point, but more work could continue later
- the long activity sentence ending in `Ω` means full idle: genuinely awaiting a new prompt
- the exact activity may vary by pony, but every approved full-idle line must still end with one of the approved idle suffixes, such as `awaiting new instructions. Ω` or `waiting for new work. Ω`
- the agent must not emit either idle marker when it still needs required user input
- approvals, escalations, and required clarification questions must not include either idle marker

## Draft Preservation

While in `ready`, the user may have a partially typed draft in the line editor.

That draft must survive:

- arrival of queued agent prompts
- notices about pending agent work
- queue-driven runs that start after other submitted input

Requirements:

- the draft text must be restorable unchanged
- if the editor supports it, cursor and edit state should also be restored
- queued notices must not destroy, overwrite, or silently submit the user's draft

## Editor UX Requirement

The parked host experience should feel like Codex, not like a shell transcript.

Requirements:

- scrolling backward should move line by line without pane redraw jumps or mixed shell noise
- Codex output history and parked-editor input must not share one messy inline transcript
- the parked host should present a real editor surface, not a raw shell prompt
- resuming after a stopping point should preserve a stable reading history instead of appending shell job-control artifacts like `zsh: suspended`

In practice, this means the final host should prefer a dedicated editor surface such as the `prompt_toolkit` host over a reclaimed shell prompt, and it should avoid forcing Codex into degraded inline rendering modes that damage scrollback quality.

When a shell launcher is used as the entrypoint, that launcher shell must still preload the pony prompt identity before starting the session host. If the foreground host is interrupted or suspended, control should fall back to a branded pony shell prompt instead of a raw project shell that requires a manual recovery command such as `tia`.

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
- prompts enqueued during a run are deferred until the next `ready`
- user-submitted prompts take precedence at `ready`
- otherwise queued items run FIFO

## Twilight Dispatch Semantics

Twilight sends messages to workers whenever she receives new instructions.

Those messages are not executed immediately by "waking" workers. Instead:

- Twilight enqueues the resulting agent prompt(s)
- any other agent may also enqueue agent prompt(s), including requests directed back to Twilight
- the line-editor host continues watching the queue
- the next queued item starts when the system is idle

## State Publication

When a worker changes `pony/work/*.md` or `pony/team.coordination/*.status.md` in a way that affects coordination, it should also publish a concise mailbox notice to Twilight in the same run that names the exact state delta and the file or field Twilight should update. If another pony must act on that change, the sender should also issue a direct `/tell` in the same run, and the runtime should accept either the pony's short alias or full display name for delivery. Twilight then decides whether that change also needs Spike or another pony to update documentation, and Twilight tells that pony directly. The project-root files are authoritative targets; if they are out of reach, the mailbox notice is the write request to Twilight instead of a mirror-only source of truth.

Mailbox files are notification lanes, not restart-state storage. If a fact must survive reboot, it must be recorded in the authoritative worker state files or explicitly escalated to Twilight as an exact write request naming the target file and field to update.

When a worker is blocked on a missing connection string, secret, endpoint, approval, or similar external prerequisite, the canonical worker state should record:

- the exact missing artifact
- who owns or is expected to supply it
- whether the worker can proceed with any partial slice
- the next unblock action or recipient of the escalation

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
