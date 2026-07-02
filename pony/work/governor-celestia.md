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
- the Celestia launcher now exports a dedicated `celestia` Codex profile so this path can diverge without changing the worker ponies
- prefer updating the governance summary in `pony/team.coordination/multi.agent.control.md` when policy changes
