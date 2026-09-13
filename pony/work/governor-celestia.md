# Princess Celestia Workfile

Purpose: Celestia's local governance scratchpad for source-repo policy and coordination-boundary decisions.
Contract: Not the shared day-to-day coordination authority. Durable operational state belongs with Twilight's shared coordination mechanism unless the user explicitly assigns source-repo governance maintenance here.

Project: agenic-pony-system
Branch: main

Status: active
Scope: source-repo governance and system rule-setting
Notes:
- govern the agenic pony system from the source repo rather than from installed target-project runtime state
- define rules and maintenance boundaries for Twilight coordinators and the other ponies
- stay above day-to-day target-project coordination so source-of-truth maintenance remains easier to reason about
- keep startup behavior, launchers, prompts, and docs coherent when governance rules change
- normal Celestia launches should carry their required Codex settings explicitly instead of depending on a `~/.codex` profile file; if a manual Codex profile is used, its canonical name is `celestia`
- prefer updating the governance summary in `pony/team.coordination/multi.agent.control.md` when policy changes
- Plan A for Codex de-ponying: keep generic launcher/runtime Codex configuration in `agenic-pony-system`, but treat in-Codex pony IPC and `/tell` behavior as the removable or feature-gateable layer inside `codex-rs`
- Plan B for runtime transport: unify `/tell` delivery so project-local runtime logs and any legacy global `/tmp/codex-pony-*.jsonl` lane cannot diverge silently
- approved policy direction: ambiguous `/tell` aliases stay team-local by default, while fully qualified generated-roster aliases such as `<project>:Twilight Sparkle` may cross repo boundaries; Celestia remains the unique global governance identity
- restart capsule:
  - task: source-governance pony-tell subject/body enhancement landed and distributed; clipboard-read support remains pending design/implementation
  - why: on Thursday, August 28, 2026, the user directed the source-first governance path; `pony-tell` now uses a 40-character implicit subject cap and direct `Subject:`/`Body:` parsing, with refreshed installs sent to EVH, Handshake, and Codex
  - files: pony/bin/pony-tell; tests/test_pony_tell.py; pony/memory/celestia.md; pony/work/governor-celestia.md
  - next: await the next governance task; if clipboard support is assigned, design it in agenic source and distribute via managed project refresh
  - blocker: none recorded
  - 2026-09-13 reconciliation: source launcher and parked-host paths now select available models from the Codex cache. On the current cache, Celestia falls back from `gpt-5.4` to `gpt-5.6-terra`; ordinary workers fall back from `gpt-5.4-mini` to `gpt-5.6-luna`. The current Celestia session is healthy; this takes effect at a fresh launch. Codex Twilight's inbound letter registered the live cross-project target, and Celestia replied successfully to `codex:Twilight Sparkle` (`1911df60-9f5c-49d0-8141-d74309c3f84c`).
  - 2026-09-13 startup/continuity change: startup context now authorizes read-only orientation only; ponies must await an explicit user or Twilight instruction before acting. Each launcher retains a private, project-local 1,000-line terminal-output tail for crash recovery, without treating it as coordinator authority. Source validation passed; deployment is required for Handshake, EVH, and Codex.
  - 2026-09-13 durable `/tell` policy: Codex TUI can append a message to a configured recipient's inbox while that recipient is offline. However, its current chat log expires after one hour and coalesces unread messages by sender. That is strictly ephemeral IPC. Durable governance/enhancement requests need a TUI-defined delivery class retained until explicit acknowledgement; source launchers alone cannot supply it.
