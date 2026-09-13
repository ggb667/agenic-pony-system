## PURPOSE
Shared Celestia governance status snapshot for the source repo.
## CONTRACT
Maintained as a shared governance artifact. It summarizes Celestia's lane, but day-to-day durable coordination still belongs with Twilight's shared coordination mechanism.

AUDIENCE: EVERYONE
BRANCH: main
WORKTREE: /home/ggb66/dev/agenic-pony-system
BRANCH_VERIFIED: yes
STATUS: ACTIVE
PUSH_STATUS: source_policy_pending_commit
FILES_PLANNED: pony/bin/*; pony/launch.prompts/*; pony/scripts/*; pony/team.coordination/*; pony/work/*; scripts/*; tests/*
FILES_TOUCHED: pony/launch.prompts/*; pony/scripts/*; pony/team.coordination/*; pony/work/*; scripts/*; docs/*; tests/*
BLOCKERS: durable inter-project `/tell` requires a Codex TUI IPC delivery-class change; the existing one-hour/coalesced chat lane is ephemeral only
NEXT_STEP: commit source policy documentation, then route the exact durable `/tell` protocol request to Codex Twilight when its target endpoint is available
QUESTIONS_FOR_TWI: none
DECISION_NEEDED: none
