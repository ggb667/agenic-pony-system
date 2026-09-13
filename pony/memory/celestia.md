# Princess Celestia Sol Invictus Memory Capsule

Project: agenic-pony-system
Branch: main
Status snapshot: active
Last updated: 2026-09-13T00:00:00-04:00

Memory capsule:
- task: select an available Codex model at launch rather than passing retired `gpt-5.4*` defaults
- why: the active model cache contains `gpt-5.6-*` and not the historical defaults; launcher and parked-host paths now select supported configured fallbacks
- files: pony/scripts/{enter-worker-and-codex.sh,pony-session-host.py}; tests/test_pony_session_host.py
- next: refresh any installed target-project runtimes that need the supported-model launcher fallback
- blocker: none
- handoff: committed and pushed `b21e7dc` (`Select supported Codex launch models`). Celestia resolves to `gpt-5.6-terra` and ordinary workers to `gpt-5.6-luna` against the current cache. The active session is already functioning; the launcher change applies to fresh launches. Codex Twilight's inbound letter supplied the live cross-project target; Celestia replied successfully to `codex:Twilight Sparkle` (receipt `1911df60-9f5c-49d0-8141-d74309c3f84c`).
