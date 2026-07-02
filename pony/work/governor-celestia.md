# Princess Celestia Workfile

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
