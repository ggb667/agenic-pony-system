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
  - task: harden startup prompt-compliance guidance and propagate it into installed runtimes
  - why: on Wednesday, August 26, 2026, Twilight reported that Applejack treated the required no-tool startup self-brief as a stopping point despite a concrete Current condition task; source guidance now explicitly requires immediate post-brief initialization and immediate correction of non-file-changing mistakes, and the installed runtimes for EVH, Handshake, and Codex were refreshed from source in the same run
  - files: pony/launch.prompts/{aj,fs,pinkie,rarity,rd,spike,twi}.txt; pony/scripts/{enter-worker-and-codex.sh,pony-session-host.py,start-session.sh}; docs/{project-installation.md,runtime-loop.md}; pony/team.coordination/{multi.agent.control.md,source.runtime.summary.md}
  - next: verify the refreshed installed runtimes surface the hardened startup wording during actual worker launches in EVH, Handshake, and Codex
  - blocker: none recorded
