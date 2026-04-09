# Twilight Workfile

Project: agenic-pony-system
Branch: main

Status: active
Scope: coordinator bring-up and source-of-truth maintenance
Notes:
- keep `agenic-pony-system` as the source of truth for launcher/runtime behavior, prompts, and docs
- keep the agenic source repo launcher set limited to Twi while the source-repo special case is in effect
- validate worker launcher behavior from installed target projects such as `Handshake/pony`, not from ad hoc agenic worker tabs
- keep Handshake launcher installs and mirrored prompt/work text aligned as the active validation target
- initial queue/input runtime scaffolding now exists under `pony/runtime/` with `pony/scripts/queue-runtime.sh`
- next implementation area after launcher stability: validate the runtime behavior through Handshake Twi/AJ launchers, then continue the remaining `docs/runtime-loop.md` behavior
