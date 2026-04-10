[[ -x ./pony/bin/codex-pony ]] || return 0

pony_project_root() {
  if git -C "${AGENIC_PROJECT_ROOT:-$PWD}" rev-parse --show-toplevel >/dev/null 2>&1; then
    git -C "${AGENIC_PROJECT_ROOT:-$PWD}" rev-parse --show-toplevel
  else
    printf '%s\n' "${AGENIC_PROJECT_ROOT:-$PWD}"
  fi
}

AGENIC_PROJECT_ROOT="$(pony_project_root)"
AGENIC_PROJECT_PONY_DIR="$AGENIC_PROJECT_ROOT/pony"
AGENIC_PROJECT_PONY_RUNTIME_DIR="$AGENIC_PROJECT_PONY_DIR/runtime"
AGENIC_PROJECT_PONY_RUNTIME_DRAFT_PATH="$AGENIC_PROJECT_PONY_RUNTIME_DIR/user.draft"
AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_PATH="$AGENIC_PROJECT_PONY_RUNTIME_DIR/pending.notice"
AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_SEEN_PATH="$AGENIC_PROJECT_PONY_RUNTIME_DIR/pending.notice.seen"

twilight()   { export PERSONALITY=TWILIGHT_SPARKLE; }
twi()        { export PERSONALITY=TWILIGHT_SPARKLE; }
rainbow()    { export PERSONALITY=RAINBOW_DASH; }
rd()         { export PERSONALITY=RAINBOW_DASH; }
dash()       { export PERSONALITY=RAINBOW_DASH; }
dashie()     { export PERSONALITY=RAINBOW_DASH; }
pinkie()     { export PERSONALITY=PINKIE_PIE; }
rarity()     { export PERSONALITY=RARITY; }
rares()      { export PERSONALITY=RARITY; }
applejack()  { export PERSONALITY=APPLEJACK; }
aj()         { export PERSONALITY=APPLEJACK; }
shy()        { export PERSONALITY=FLUTTERSHY; }
fluttershy() { export PERSONALITY=FLUTTERSHY; }
flutters()   { export PERSONALITY=FLUTTERSHY; }
spike()      { export PERSONALITY=SPIKE; }
w()          { export WORKING_ON="$1"; }
clearwork()  { unset WORKING_ON; }
clearpony()  { unset PERSONALITY; }
clearrole()  { unset PERSONALITY WORKING_ON; }
codexpony()  { ./pony/bin/codex-pony "$@"; }
ponyruntime() { ./pony/scripts/queue-runtime.sh "$@"; }
ponyqueue()  { ./pony/scripts/queue-runtime.sh list; }
ponycontinue() {
  local next_id
  next_id="$(./pony/scripts/queue-runtime.sh next)"
  [[ -n "$next_id" ]] || return 0
  codexpony "$(./pony/scripts/queue-runtime.sh active-prompt)"
  local exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    ./pony/scripts/queue-runtime.sh pop "$next_id"
    ./pony/scripts/queue-runtime.sh complete
  fi
  return $exit_code
}

if [[ -o interactive ]]; then
  autoload -Uz add-zsh-hook

  pony_runtime_sync_notice() {
    ./pony/scripts/queue-runtime.sh init >/dev/null 2>&1 || return 0
    ./pony/scripts/queue-runtime.sh pending-notice >/dev/null 2>&1 || true
    if [[ -s "$AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_PATH" ]] && ! cmp -s "$AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_PATH" "$AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_SEEN_PATH"; then
      printf '\n%s\n' "$(<"$AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_PATH")"
      cat "$AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_PATH" > "$AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_SEEN_PATH"
    fi
  }

  pony_runtime_draft_restore() {
    [[ -o zle ]] || return 0
    if [[ -z "$BUFFER" && -s "$AGENIC_PROJECT_PONY_RUNTIME_DRAFT_PATH" ]]; then
      BUFFER="$(<"$AGENIC_PROJECT_PONY_RUNTIME_DRAFT_PATH")"
      CURSOR=${#BUFFER}
    fi
  }

  pony_runtime_draft_save() {
    [[ -o zle ]] || return 0
    printf '%s' "$BUFFER" >| "$AGENIC_PROJECT_PONY_RUNTIME_DRAFT_PATH"
  }

  add-zsh-hook precmd pony_runtime_sync_notice
  zle -N zle-line-init pony_runtime_draft_restore
  zle -N zle-line-finish pony_runtime_draft_save
fi