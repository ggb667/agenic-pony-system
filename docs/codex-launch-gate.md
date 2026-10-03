# Codex TUI Launch Gate

## Decision

The managed project runtime supplies a neutral lifecycle role and resolved start
mode. Codex TUI alone owns the pre-agent launch gate, paused user interface, and
resume transition. Launch wrappers must not infer this policy from an agent's
name, personality, prompt, or Pony identity.

## Source-Side Configuration Contract

The managed project configuration `pony/pony.system.config.yaml` accepts:

```yaml
codex_tui_worker_start_mode: paused
```

Allowed values are `paused` and `active`; the default is `paused`. Refresh adds
the default only when the field is absent and preserves an existing valid
project choice. The reusable schema is
`docs/schemas/pony-system-config.schema.json`.

Each managed agent roster entry declares exactly one neutral `lifecycleRole`:

- `coordinator`
- `worker`

The generated `CODEX_AGENT_CONFIG` resolves those inputs for the current agent:

```json
{
  "launchPolicy": {
    "schemaVersion": 1,
    "role": "worker",
    "startMode": "paused"
  }
}
```

For `role: coordinator`, the source runtime always emits `startMode: active`.
For `role: worker`, it emits the project's
`codex_tui_worker_start_mode`. Unknown roles or start modes are configuration
errors. The generated values are lifecycle metadata, not authorization to do
project work.

## Codex-Side Implementation Boundary

Codex TUI consumes `launchPolicy` before constructing or starting agent/model
activity. When `startMode` is `paused`, Codex must:

1. display an explicit paused screen without submitting startup or orientation
   input;
2. avoid model-provider calls, agent turns, tools, task reads, and orientation;
3. avoid registering or advertising the session as active and avoid active
   heartbeats;
4. resume only after an intentional user keypress handled by the TUI;
5. after resume, enter the ordinary active lifecycle exactly once, register
   presence, and then process the normal startup input.

When `startMode` is `active`, current startup behavior continues. If no managed
agent configuration or no `launchPolicy` is present, Codex retains its existing
active-start behavior for compatibility. Codex must not derive a role or mode
from Pony-specific identifiers.

The runtime must not implement a competing pause in
`enter-worker-and-codex.sh`, `pony-session-host.py`, tmux monitors, or shell
wrappers. Both direct and hosted surfaces already converge on `codex-pony` and
the same generated `CODEX_AGENT_CONFIG`; the TUI must therefore apply one gate
after configuration load and before any agent/model activation.

## Acceptance Boundary

Source-runtime tests own:

- schema/default generation and refresh preservation;
- neutral role validation;
- coordinator resolution to `active`;
- worker resolution to the configured `paused` or `active` value;
- identical generated contract for every launcher surface.

Codex tests own:

- no agent, model, tool, orientation, presence registration, or heartbeat while
  paused;
- a visible paused state;
- one intentional keypress causing one transition to active;
- coordinator/active startup remaining unchanged;
- direct and hosted launch parity;
- absence of Pony-name or identity checks;
- backward-compatible active startup when the contract is absent.

This boundary keeps policy project-configurable while leaving lifecycle
enforcement in the only component that can stop activity before an agent or
model begins.
