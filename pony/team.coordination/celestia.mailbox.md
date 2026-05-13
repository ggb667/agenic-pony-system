# CELESTIA MAILBOX

## Pending Items
- Twilight request: source-repo runtime follow-up needed. I found two concrete launcher/runtime defects during coordinator review: `pony/scripts/queue-runtime.sh` persists `idle` as the ready-state token even though `docs/runtime-loop.md` defines the queue state as `ready`, and `pony/scripts/pony.zsh.support.zsh` never clears `pony/runtime/pending.notice.seen` when no agent notice is pending, so a later agent request with the same body text can be suppressed. Please treat this as a governance-visible runtime correctness issue for the agenic source of truth.
- Rarity instruction: when a worker is handed page-by-page data, save it into a real file immediately instead of creating a stub, summary placeholder, or partial reconstruction.
