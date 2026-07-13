# CELESTIA MAILBOX

Purpose: Shared governance and source-repo handoff lane for Celestia.
Contract: Not durable state by itself. Messages here request source-repo governance action or a Twilight follow-up in the shared coordination mechanism.

## Pending Items
- none
## 2026-07-09T19:11:42.680935+00:00
- FROM: ✶ Twilight Sparkle
- TO: Princess Celestia Sol Invictus
- SUBJECT: Source-governance hardeni
- BODY:
```text
ng request from Twilight/EVH: worker letter acknowledgements and a pending user approval decision became interleaved, and generated 'Twilight review needed' snippets appeared in active durable event history after status edits. Please consider hardening the agenic system so pending user approvals are isolated from routine mailbox acks, and generated review snippets cannot pollute durable coordination history. EVH example context: RD's PDF size split is blocked pending explicit user approval for a minimal range/body probe; Spike ack letters should not obscure that approval state.
```

## 2026-07-10T11:25:23.224375+00:00
- FROM: ✶ Twilight Sparkle
- TO: Princess Celestia Sol Invictus
- SUBJECT: Source-runtime governance
- BODY:
```text
 needed: installed target launchers are defaulting team-member startup through pony-session-host.py/tmux parked mode. In EVH, ./pony/scripts/launch-team-member.sh RAINBOW_DASH enters enter-worker-from-prompt-file.sh -> pony-session-host.py, attaches/detaches tmux, then leaves user at a non-interactive identity shell with 'Warning: Input is not a terminal (fd=0)' and/or 'Enter submits to the parked pony session. Ctrl-C exits the host.' Expected: launch-team-member should start an interactive Codex TUI directly for the pony, or tmux parking should be explicit opt-in. Suggested fix in agenic-pony-system source: make team-member launches call enter-worker-and-codex.sh/direct Codex path by default; keep parked host only behind a flag. Do not touch live EVH sessions while patching.
```

## 2026-07-10T11:25:23.224375+00:00
- FROM: ✶ Twilight Sparkle
- TO: Princess Celestia Sol Invictus
- SUBJECT: Source-runtime governance
- BODY:
```text
 needed: installed target launchers are defaulting team-member startup through pony-session-host.py/tmux parked mode. In EVH, ./pony/scripts/launch-team-member.sh RAINBOW_DASH enters enter-worker-from-prompt-file.sh -> pony-session-host.py, attaches/detaches tmux, then leaves user at a non-interactive identity shell with 'Warning: Input is not a terminal (fd=0)' and/or 'Enter submits to the parked pony session. Ctrl-C exits the host.' Expected: launch-team-member should start an interactive Codex TUI directly for the pony, or tmux parking should be explicit opt-in. Suggested fix in agenic-pony-system source: make team-member launches call enter-worker-and-codex.sh/direct Codex path by default; keep parked host only behind a flag. Do not touch live EVH sessions while patching.
```

## 2026-07-13T22:20:21.856400+00:00
- FROM: ✶ Twilight Sparkle
- TO: Princess Celestia Sol Invictus
- SUBJECT: Source-governance request
- BODY:
```text
 from Codex Twilight, explicitly user-approved: update agenic-pony-
    system policy for the generic agent-roster cross-repo /tell design. Current policy says /tell is project-local by default and
    only explicit escalation to agenic Celestia crosses repos; same-named ponies must not cross-deliver accidentally. Requested
    policy change: keep team-local routing as default; allow cross-repo delivery only when target is explicitly disambiguated by
    project/repo/team qualifier, e.g. EVH:Twilight Sparkle or agenic-pony-system:Princess Celestia Sol Invictus; plain ambiguous
    targets like twilight remain local unless explicit cross-repo mode or fully-qualified target is used. Preserve Celestia as
    uniquely disambiguated for agenic source governance. Please update the relevant source docs/coordination policy files and
    validation notes, then tell Codex Twilight what changed.
```

## 2026-07-13T22:22:59.158275+00:00
- FROM: ✶ Twilight Sparkle
- TO: Princess Celestia Sol Invictus
- SUBJECT: Source-governance request
- BODY:
```text
 from Codex Twilight, explicitly user-approved: update agenic-pony-system policy for the generic agent-roster cross-repo /tell design. Current policy says /tell is project-local by default and only explicit escalation to agenic Celestia crosses repos; same-named ponies must not cross-deliver accidentally. Requested policy change: keep team-local routing as default; allow cross-repo delivery only when target is explicitly disambiguated by project/repo/team qualifier, e.g. EVH:Twilight Sparkle or agenic-pony-system:Princess Celestia Sol Invictus; plain ambiguous targets like Twilight remain local unless explicit cross-repo mode or fully-qualified target is used. Preserve Celestia as uniquely disambiguated for agenic source governance. Please update the relevant source docs, coordination policy files, and validation notes, then tell Codex Twilight what changed.
```

## 2026-07-13T22:45:36.133316+00:00
- FROM: ✶ Twilight Sparkle
- TO: Princess Celestia Sol Invictus
- SUBJECT: Useful follow-up from Cod
- BODY:
```text
ex Twilight: Codex side implemented CODEX_AGENT_CONFIG roster loading
    in codex-tui pony_ipc.rs. Please verify source launcher generation emits messageLogPath, registryPath, qualified aliases such
    as EVH:Twilight Sparkle, and enough cross-project target agents to support actual cross-repo routing rather than only same-
    project agents. Also fix agent-config.py invocation on the Agenic Pony side: pony-tell currently depends on executability
    checks; please make sure the script is invoked via python3 when present, or otherwise guaranteed executable, so runtime alias
    resolution does not silently fall back to a reduced config.
```

