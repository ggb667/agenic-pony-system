# SOURCE RUNTIME SUMMARY

Purpose: Compact source-repo launch summary for Celestia and Twilight.
Contract: Distills the stable source-repo rules from `README.md`, `docs/runtime-loop.md`, and `docs/project-installation.md` so source-governance launches do not need to reread those broader docs every time.

## Source Repo Special Case

- `agenic-pony-system` is the reusable source of truth for launcher behavior, prompts, install logic, and design docs
- the live runtime for ordinary project work belongs inside each target project's local `pony/` tree
- the source repo is a special case: Celestia governs source-repo policy, Twilight remains the coordinator, and worker-launch validation belongs in installed target-project runtimes such as `/home/ggb66/dev/codex/pony`

## Repo Boundary

- source-repo governance work stays in `/home/ggb66/dev/agenic-pony-system`
- installed target-project runtime churn belongs in the target project unless the user explicitly assigns cross-repo governance work
- bootstrap hops through source-layer scripts are expected managed plumbing, not a policy conflict, as long as control returns to the active project's local pony state before work begins

## Shared Coordination Model

- Twilight maintains the shared authoritative coordination mechanism
- worker-local `pony/work/*.md` and `pony/team.coordination/*.status.md` files are workspace artifacts unless Twilight is explicitly assigned to maintain them
- when a worker causes a durable shared-state change, the worker should tell Twilight the exact update to record in the same run
- before a worker stops at idle or handoff, it should refresh a concise restart capsule in its assigned workfile; if that capsule changes shared durable state, the worker should tell Twilight the exact delta to record in the same run
- if a worker memory capsule exists, the worker should read it at startup before acting and refresh it when shutdown or restart context materially changes
- when the user says the project is shutting down, Twilight should collect save-memory and status reports from the live agents before saving Twilight's own memory capsule
- direct `/tell` transport should keep ambiguous targets local by default so live teams in different repos do not cross-deliver same-named pony traffic by accident
- generated agent roster config may also expose explicit cross-repo targets such as `<project>:Twilight Sparkle`; those fully qualified targets may route across repo boundaries when the active registry/message bus includes both live sessions
- the generated `CODEX_AGENT_CONFIG` payload should carry `messageLogPath`, `registryPath`, the local roster, and any live cross-project targets discovered on that same bus so Codex and shell helpers share one routing surface
- `Princess Celestia Sol Invictus` remains the uniquely disambiguated source-governance identity and may resolve globally; unqualified `Celestia` implies the `agenic-pony-system` source-repo governance lane, so repo and governance scope are already implicit in the recipient
- simple live `/tell` pings, acknowledgements, and short coordination notes stay in the live IPC lane by default and should normally receive a short direct `/tell` reply rather than mailbox or history churn
- pending user approvals should stay isolated from routine acknowledgement traffic and should remain visible in a dedicated coordinator approval lane until the user answers
- generated `Twilight review needed` helper text should stay out of durable coordinator history and live in a review queue or todo surface instead
- if a blocker depends on a missing secret, endpoint, approval, or similar prerequisite, the shared coordination state must name the exact missing artifact, expected owner, and next unblock step
- any Twilight runtime acting for the agenic source-governance lane must be able to append to the resolved lane `messageLogPath`; if the path is correct but the append fails, classify the result as a permission-only delivery blocker rather than a routing defect

## Install And Validation Boundaries

- source changes land in `agenic-pony-system`
- installed copies under `<project-root>/pony/` should be refreshed when managed prompts, scripts, or runtime files change
- project-local `pony/runtime/runtime.state` should use `ready` as the canonical parked token; stale `idle` values should be normalized or treated as drift
- lightweight parked-host behavior and editor/tmux continuity should not be Celestia-only; ordinary pony relaunches should preserve local draft/history state unless the operator explicitly resets them or the runtime is removing stale transport state
- runtime validation should happen from the installed target project's `pony/` tree
- `codex-rs` edits are reserved for Codex UI behavior, not general pony policy

## Codex De-Ponying Plan A

- the pony agents do run a real Codex binary today; the current wrapper path ends at `pony/bin/codex-pony`, which in this environment prefers `/home/ggb66/dev/codex/codex-rs/target/debug/codex-tui`
- keep generic launch-time Codex configuration in `agenic-pony-system`: model selection, approval mode, sandbox mode, prompt styling, startup prompts, and hidden instruction file wiring remain wrapper/runtime responsibilities
- treat the embedded pony IPC inside `codex-rs` as the first de-ponying target, not the generic wrapper-layer Codex launch configuration
- Plan A: remove or feature-gate the in-Codex pony IPC and `/tell` integration (`tui/src/pony_ipc.rs`, pony chat wiring, pony app events, and `/tell` slash-command handling) while preserving ordinary direct Codex launch from the pony runtime
- under Plan A, shell/runtime helpers such as `pony/bin/pony-tell`, launcher env handling, and project-local coordination files may remain in the pony system; only the Codex-internal pony behavior is being separated
- risk boundary for Plan A: removing pony IPC from Codex without replacement will drop in-TUI `/tell`, live registry heartbeat, and automatic incoming pony-message delivery even though the launcher still reaches Codex correctly
- preferred follow-up after Plan A documentation: decide whether pony-to-pony IPC should live entirely outside Codex or return later behind an explicit feature flag

## `/tell` Transport Plan B

- current evidence shows two live transport lanes can diverge: project-local runtime logs under `<project>/pony/runtime/...` and legacy global Codex pony IPC logs under `/tmp/codex-pony-*.jsonl`
- the source-repo Celestia session successfully wrote message `01c5fdc7-c596-42a7-b542-4acd33d2daaa` into `/home/ggb66/dev/agenic-pony-system/pony/runtime/pony.chat.jsonl`, while Codex Twilight was inspecting the Codex project runtime and legacy `/tmp` evidence instead
- Plan B: unify `/tell` transport so project-local routing and any legacy global fallback cannot silently diverge or make delivery appear successful in one lane while invisible in the active team lane
- under Plan B, the active launch context must make the selected project root, generated agent roster, chat log path, and registry path explicit enough that the sender, receiver, and validation tooling all agree on the same transport surface
- preferred resolution direction: ambiguous short aliases stay local by default, while explicit fully qualified agent aliases may cross repo boundaries through the shared generated roster; any legacy global `/tmp` lane should either be removed, feature-gated, or made visibly subordinate so it cannot masquerade as the active team transport
- minimum validation for Plan B: a sent `/tell` should be discoverable from the active team's runtime logs, live receiver registry, and receiver-side inspection commands without ambiguity about which project or branch owns the lane
