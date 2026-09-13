# Princess Celestia Sol Invictus Memory Capsule

Project: agenic-pony-system
Branch: main
Status snapshot: active
Last updated: 2026-09-13T00:00:00-04:00

Memory capsule:
- task: select an available Codex model at launch rather than passing retired `gpt-5.4*` defaults
- why: the active model cache contains `gpt-5.6-*` and not the historical defaults; launcher and parked-host paths now select supported configured fallbacks
- files: pony/scripts/{enter-worker-and-codex.sh,pony-session-host.py}; tests/test_pony_session_host.py
- next: commit and push the reconciled source change, then refresh any installed target-project runtimes that need it
- blocker: `pony-tell` cannot resolve the intended Codex Twilight recipient (`codex:Twilight`) from this session's generated roster; repair cross-project roster registration before relying on its acknowledgement path
- handoff: Celestia resolves to `gpt-5.6-terra` and ordinary workers to `gpt-5.6-luna` against the current cache. The active session is already functioning; the launcher change applies to fresh launches.
