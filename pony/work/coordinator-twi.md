# Twilight Workfile

Project: agenic-pony-system
Branch: main

Status: active
Scope: coordinator bring-up and source-of-truth maintenance
Notes:
- keep `agenic-pony-system` as the source of truth for launcher/runtime behavior, prompts, and docs
- keep Celestia as the dedicated agenic source-repo Warp launcher while Twilight remains the coordinator
- validate worker launcher behavior from installed target projects such as `Handshake/pony`, not from ad hoc agenic worker tabs
- keep Handshake launcher installs and mirrored prompt/work text aligned as the active validation target
- initial queue/input runtime scaffolding now exists under `pony/runtime/` with `pony/scripts/queue-runtime.sh`
- in the terminal and line-editor test lane, treat installed target-project `pony/` trees as expected test apparatus
- do not propose or perform `git stash`, `git restore`, worktree cleaning, or "clean preflight state" work unless the user explicitly asks for Git hygiene or the runtime test is actually blocked by a file conflict
- do not spend time reconciling generated timestamp-only churn in project-local `twi.todo.md`, `twi.status.md`, or `twi.event.stream.history.md` during runtime tests; that is not the task unless the user explicitly assigns coordination-file maintenance
- next implementation area after launcher stability: validate the runtime behavior through installed-project launchers, then continue the remaining `docs/runtime-loop.md` behavior
