# Pre-Idle Inbound Message Drain

## Decision

Codex TUI agent IPC owns the single inbound-message check performed before an
agent is allowed to enter an `Ω` idle state.

The pony runtime supplies the configured message-log and persistent receipt
paths. It must not implement a second drain cursor or competing receipt check in
`codex-tmux-monitor.sh`, `pony-session-host.py`, or another launcher helper.

## Required Invariant

Before accepting any partial or full `Ω` idle transition, Codex must check for
every inbound message appended since the recipient's last successful drain,
regardless of delivery class.

If unseen messages exist, Codex must:

1. inject each message into the active recipient session exactly once;
2. persist the corresponding receipt before advancing the drain checkpoint;
3. cancel or defer the idle transition so the recipient can process the input.

If no unseen message exists, the idle transition may proceed without invoking
the model or reparsing the entire log.

## Findings

- `pony/scripts/codex-tmux-monitor.sh` recognizes `Ω` in pane output and
  suspends Codex after two 0.4-second idle polls.
- That monitor does not inspect the configured agent message log or receipt
  ledger before suspension.
- Direct interactive launches use `enter-worker-and-codex.sh` and do not pass
  through the tmux monitor, so a monitor-only fix cannot enforce the invariant.
- Codex agent IPC already owns active-session message injection and persistent
  receipt semantics. Placing the gate there avoids duplicate cursors, duplicate
  delivery, and launcher-specific behavior.

## Cheap Check

Maintain a recipient-specific checkpoint containing the message-log identity
(for example device/inode where available) and last successfully drained byte
offset. On the pre-idle path:

1. `stat` the configured message log;
2. if identity and size are unchanged, return immediately;
3. if the file grew, read only the appended bytes from the saved offset;
4. if the file was replaced or truncated, recover safely by consulting the
   persistent receipt ledger while scanning the necessary records;
5. select records addressed to the active recipient;
6. discard IDs already present in the persistent receipt ledger;
7. inject and receipt each remaining record exactly once;
8. advance the checkpoint only through successfully parsed and handled input.

The common no-change path is one metadata check. No model call, full-log scan,
or polling loop is required.

## Concurrency And Failure Rules

- Delivery class does not affect whether a newly arrived record blocks idle.
- A partial trailing JSON line must remain pending until the append completes;
  do not advance past it.
- Receipt persistence and checkpoint advancement must not permit a crash window
  that silently drops an unseen message.
- Duplicate records or a replay after truncation/rotation are deduplicated by
  message ID through the persistent receipt ledger.
- A message appended during the drain must either be included in the same
  bounded read or remain beyond the saved offset for the next check.
- Failure to read or persist the authoritative message/receipt state must keep
  the session from silently declaring clean idle.

## Acceptance Tests

1. **No change:** repeated pre-idle checks perform no injection and do not scan
   the complete log.
2. **Ephemeral arrival:** an unseen ephemeral message appended before `Ω` is
   injected once and idle is cancelled.
3. **Durable arrival:** an unseen durable message behaves identically for the
   pre-idle gate.
4. **Multiple arrivals:** all newly appended recipient messages are injected in
   log order exactly once.
5. **Other recipient:** records addressed elsewhere do not block this agent's
   idle transition.
6. **Already receipted:** a known message ID is not reinjected.
7. **Append race:** a message arriving while the check runs is processed in
   that check or remains visible to the next one.
8. **Partial record:** an incomplete trailing record is not lost and is handled
   after completion.
9. **Rotation/truncation:** recovery uses receipts to avoid both loss and
   duplicate injection.
10. **Direct and hosted launch parity:** the same Codex-side tests cover direct
    launches and tmux-hosted launches without a separate monitor drain.

## Non-Goals

- Do not launch every pony merely to repopulate presence state.
- Do not add a second message-drain implementation to the pony monitor.
- Do not make `Ω` itself responsible for durable coordination storage.
- Do not treat mailbox notification files as authoritative receipt ledgers.
