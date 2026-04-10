#!/usr/bin/env bash
set -euo pipefail

personality="${1:?missing personality}"
workfile="${2:?missing workfile}"
rootdir="${3:?missing rootdir}"
initial_prompt="${4-}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/pony-paths.sh"
load_project_paths "$(cd "$script_dir/../.." && pwd)"
repo_codex_pony="$(pony_bin_path codex-pony)"
postflight_script="$(pony_script_path worker-postflight.sh)"
monitor_script="$(pony_script_path codex-tmux-monitor.sh)"
idle_sentinel="$(idle_sentinel_for_personality "$personality" || true)"
partial_idle_sentinel="$(partial_idle_sentinel)"

resolve_path() {
  local path="${1:-}"
  if [[ -e "$path" ]]; then
    printf '%s\n' "$path"
  else
    printf '%s\n' "$path"
  fi
}

workfile="$(resolve_path "$workfile")"
rootdir="$(resolve_path "$rootdir")"

export PERSONALITY="$personality"
export WORKING_ON="$workfile"
export INITIAL_PROMPT="$initial_prompt"

if [[ ! -f "$workfile" ]]; then
  echo "ERROR: workfile not found: $workfile" >&2
  exit 1
fi

worker_slug="$(worker_slug_for_personality "$personality" || printf 'worker')"
tmux_session_name="pony-${AGENIC_PROJECT_SLUG}-${worker_slug}"
tmux_socket_path="$AGENIC_PROJECT_PONY_AGENTS_DIR/tmux.${worker_slug}.sock"

if [[ -z "${TMUX:-}" ]] && [[ -t 0 ]] && [[ -t 1 ]] && command -v tmux >/dev/null 2>&1; then
  tmux -S "$tmux_socket_path" has-session -t "$tmux_session_name" >/dev/null 2>&1 && \
    tmux -S "$tmux_socket_path" kill-session -t "$tmux_session_name" >/dev/null 2>&1 || true
  exec tmux -S "$tmux_socket_path" new-session -s "$tmux_session_name" \
    "cd $(printf '%q' "$rootdir") && $(printf '%q' "$0") $(printf '%q' "$personality") $(printf '%q' "$workfile") $(printf '%q' "$rootdir") $(printf '%q' "$initial_prompt")"
fi

cd "$rootdir"
preflight_result="$(
  "$(pony_script_path worker-preflight.sh)" \
    "$PERSONALITY" \
    "$WORKING_ON" \
    "$PWD"
)"

pony_ensure_layout_dirs
zdotdir="$(mktemp -d "$AGENIC_PROJECT_PONY_AGENTS_DIR/zdot.XXXXXX")"

cat >"$zdotdir/.zshrc" <<'EOF'
export PATH="$AGENIC_PROJECT_PONY_BIN_DIR:$PATH"
export REPO_ROOT="$AGENIC_PROJECT_ROOT"
export WORKER_RUNTIME_ROOT="$AGENIC_PROJECT_PONY_AGENTS_DIR"
mkdir -p "$WORKER_RUNTIME_ROOT"

worker_runtime_slug() {
  local raw="${PERSONALITY:-worker}"
  raw="${raw:l}"
  raw="${raw//[^a-z0-9]/-}"
  printf '%s' "$raw"
}

export HISTFILE="$WORKER_RUNTIME_ROOT/$(worker_runtime_slug).zsh.history"
export SAVEHIST=1000
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
unsetopt BANG_HIST
setopt INTERACTIVE_COMMENTS
setopt NO_NOMATCH
setopt NO_BEEP
setopt PROMPT_SUBST
autoload -Uz add-zsh-hook

worker_runtime_pid_file() { printf '%s/%s.shell.pid' "$WORKER_RUNTIME_ROOT" "$(worker_runtime_slug)"; }
worker_runtime_codex_pid_file() { printf '%s/%s.codex.pid' "$WORKER_RUNTIME_ROOT" "$(worker_runtime_slug)"; }
worker_runtime_codex_job_file() { printf '%s/%s.codex.job' "$WORKER_RUNTIME_ROOT" "$(worker_runtime_slug)"; }
worker_runtime_codex_monitor_pid_file() { printf '%s/%s.codex.monitor.pid' "$WORKER_RUNTIME_ROOT" "$(worker_runtime_slug)"; }
worker_runtime_state_file() { printf '%s/%s.state' "$WORKER_RUNTIME_ROOT" "$(worker_runtime_slug)"; }

worker_write_runtime_files() {
  printf '%s\n' "$$" > "$(worker_runtime_pid_file)"
  cat >"$(worker_runtime_state_file)" <<STATE
PERSONALITY=${PERSONALITY:-}
WORKING_ON=${WORKING_ON:-}
WORKER_ROOTDIR=${WORKER_ROOTDIR:-}
WORKER_PREFLIGHT_RESULT=${WORKER_PREFLIGHT_RESULT:-}
STATE=${1:-shell}
CODEX_PID=${WORKER_CODEX_PID:-}
STATE
}

worker_remove_runtime_files() {
  rm -f -- \
    "$(worker_runtime_pid_file)" \
    "$(worker_runtime_codex_pid_file)" \
    "$(worker_runtime_codex_job_file)" \
    "$(worker_runtime_codex_monitor_pid_file)" \
    "$(worker_runtime_state_file)"
}

typeset -gi WORKER_WAKE_REQUESTED=0
typeset -gi WORKER_CODEX_ACTIVE=0
typeset -gi WORKER_EDITOR_ACTIVE=0
typeset -gi WORKER_EDITOR_LOOP_ACTIVE=0
typeset WORKER_CODEX_PID=""
typeset WORKER_CODEX_JOB=""
typeset WORKER_QUEUE_ITEM_ID=""
typeset WORKER_LAST_SUBMISSION_KIND=""

worker_prompt_glyph() {
  case "${PERSONALITY:-}" in
    TWI|TWILIGHT|TWILIGHT_SPARKLE) printf '✶' ;;
    AJ|APPLEJACK) printf '🍎' ;;
    PINKIE|PINKIE_PIE) printf '🎈' ;;
    SHY|FLUTTERS|FLUTTERSHY) printf '🦋' ;;
    RARES|RARITY) printf '💎' ;;
    DASH|RAINBOW|RAINBOW_DASH) printf '⚡' ;;
    SPIKE) printf '🐲' ;;
    *) printf '%%#' ;;
  esac
}

worker_display_name() {
  case "${PERSONALITY:-}" in
    TWI|TWILIGHT|TWILIGHT_SPARKLE) printf 'Twilight' ;;
    AJ|APPLEJACK) printf 'Applejack' ;;
    PINKIE|PINKIE_PIE) printf 'Pinkie' ;;
    SHY|FLUTTERS|FLUTTERSHY) printf 'Fluttershy' ;;
    RARES|RARITY) printf 'Rarity' ;;
    DASH|RAINBOW|RAINBOW_DASH) printf 'Rainbow' ;;
    SPIKE) printf 'Spike' ;;
    *) printf '%s' "${PERSONALITY:-agent}" ;;
  esac
}

set_worker_prompt() {
  local branch=""
  local prompt_glyph=""
  if command git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch="$(git branch --show-current 2>/dev/null || true)"
  fi
  prompt_glyph="$(worker_prompt_glyph)"
  PROMPT='${PERSONALITY:-WORKER}'
  if [[ -n "${WORKING_ON:-}" ]]; then
    PROMPT+=" ${WORKING_ON}"
  fi
  PROMPT+=" %~"
  if [[ -n "$branch" ]]; then
    PROMPT+=" ${branch}"
  fi
  PROMPT+=" ${prompt_glyph} "
}

add-zsh-hook precmd set_worker_prompt
set_worker_prompt

worker_update_state() { worker_write_runtime_files "${1:-shell}"; }
worker_queue_script() { printf '%s\n' "$AGENIC_PROJECT_PONY_SCRIPTS_DIR/queue-runtime.sh"; }
worker_line_editor_script() { printf '%s\n' "$AGENIC_PROJECT_PONY_SCRIPTS_DIR/pony-line-editor.py"; }
worker_line_editor_history_file() { printf '%s/%s.editor.history' "$WORKER_RUNTIME_ROOT" "$(worker_runtime_slug)"; }
worker_line_editor_result_file() { printf '%s/%s.editor.result' "$WORKER_RUNTIME_ROOT" "$(worker_runtime_slug)"; }
worker_tmux() { tmux -S "${PONY_TMUX_SOCKET_PATH:?missing tmux socket path}" "$@"; }
worker_state_set() { "$(worker_queue_script)" state-set "${1:?missing state}" >/dev/null 2>&1 || true; }
worker_state_complete() { "$(worker_queue_script)" complete >/dev/null 2>&1 || true; }
worker_set_active_prompt() { printf '%s' "${1:-}" > "$AGENIC_PROJECT_PONY_RUNTIME_ACTIVE_PROMPT_PATH"; }
worker_clear_saved_draft() { : > "$AGENIC_PROJECT_PONY_RUNTIME_DRAFT_PATH"; }

worker_runtime_sync_notice() {
  "$(worker_queue_script)" init >/dev/null 2>&1 || return 0
  "$(worker_queue_script)" pending-notice >/dev/null 2>&1 || true
  if [[ -s "$AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_PATH" ]] && ! cmp -s "$AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_PATH" "$AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_SEEN_PATH"; then
    if [[ "${WORKER_EDITOR_ACTIVE:-0}" -eq 0 && "${WORKER_EDITOR_LOOP_ACTIVE:-0}" -eq 0 ]]; then
      printf '\n%s\n' "$(<"$AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_PATH")"
    fi
    cat "$AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_PATH" > "$AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_SEEN_PATH"
  fi
}

worker_runtime_draft_restore() {
  [[ -o zle ]] || return 0
  if [[ -z "$BUFFER" && -s "$AGENIC_PROJECT_PONY_RUNTIME_DRAFT_PATH" ]]; then
    BUFFER="$(<"$AGENIC_PROJECT_PONY_RUNTIME_DRAFT_PATH")"
    CURSOR=${#BUFFER}
  fi
}

worker_runtime_draft_save() {
  [[ -o zle ]] || return 0
  mkdir -p "$AGENIC_PROJECT_PONY_RUNTIME_DIR"
  printf '%s' "$BUFFER" >| "$AGENIC_PROJECT_PONY_RUNTIME_DRAFT_PATH"
}

worker_find_codex_job() {
  local target_pid="${1:-$WORKER_CODEX_PID}"
  jobs -l | awk -v target_pid="$target_pid" '
    {
      gsub(/^\[/, "", $1)
      gsub(/\]/, "", $1)
      if ($2 == target_pid) {
        printf "%%%s\n", $1
        exit
      }
    }
  '
}

worker_codex_is_stopped() {
  [[ -n "${WORKER_CODEX_PID:-}" ]] || return 1
  local stat
  stat="$(ps -o stat= -p "$WORKER_CODEX_PID" 2>/dev/null | tr -d '[:space:]')"
  [[ "$stat" == *T* ]]
}

worker_record_codex_job() {
  WORKER_CODEX_JOB="$(worker_find_codex_job)"
  if [[ -n "$WORKER_CODEX_JOB" ]]; then
    printf '%s\n' "$WORKER_CODEX_JOB" > "$(worker_runtime_codex_job_file)"
  else
    rm -f -- "$(worker_runtime_codex_job_file)"
  fi
}

worker_clear_codex_tracking() {
  WORKER_CODEX_PID=""
  WORKER_CODEX_JOB=""
  rm -f -- \
    "$(worker_runtime_codex_pid_file)" \
    "$(worker_runtime_codex_job_file)" \
    "$(worker_runtime_codex_monitor_pid_file)"
}

worker_finish_submission() {
  if [[ -n "${WORKER_QUEUE_ITEM_ID:-}" ]]; then
    "$(worker_queue_script)" pop "$WORKER_QUEUE_ITEM_ID" >/dev/null 2>&1 || true
  fi
  worker_state_complete
  WORKER_QUEUE_ITEM_ID=""
  WORKER_LAST_SUBMISSION_KIND=""
}

worker_prepare_submission() {
  local submission_text="${1:-}"
  if [[ -n "$submission_text" ]]; then
    WORKER_QUEUE_ITEM_ID=""
    WORKER_LAST_SUBMISSION_KIND="user"
    worker_set_active_prompt "$submission_text"
    worker_state_set "running.prompt"
    return 0
  fi
  WORKER_QUEUE_ITEM_ID="$("$(worker_queue_script)" next)"
  [[ -n "$WORKER_QUEUE_ITEM_ID" ]] || return 1
  WORKER_LAST_SUBMISSION_KIND="queue"
  return 0
}

worker_resume_codex() {
  local prompt_text=""
  if ! worker_codex_is_stopped; then
    echo 'Codex is not parked at the host prompt.'
    return 1
  fi
  if ! worker_prepare_submission "${1:-}"; then
    return 0
  fi
  prompt_text="$(cat "$AGENIC_PROJECT_PONY_RUNTIME_ACTIVE_PROMPT_PATH")"
  [[ -n "$prompt_text" ]] || return 0
  worker_record_codex_job
  if [[ -z "$WORKER_CODEX_JOB" ]]; then
    echo 'Unable to find parked Codex job.'
    return 1
  fi
  if [[ -z "${TMUX_PANE:-}" ]]; then
    echo 'No tmux pane is attached to this worker shell.'
    return 1
  fi
  worker_clear_saved_draft
  (
    sleep 0.2
    worker_tmux send-keys -t "${TMUX_PANE:-}" -l -- "$prompt_text"
    worker_tmux send-keys -t "${TMUX_PANE:-}" Enter
  ) >/dev/null 2>&1 &
  fg "$WORKER_CODEX_JOB"
  if worker_codex_is_stopped; then
    worker_finish_submission
    worker_update_state "waiting_user"
    worker_enter_line_editor_loop
  else
    worker_clear_codex_tracking
    worker_state_complete
    worker_update_state "shell"
  fi
}

worker_collect_prompt_input() {
  local editor_status=0
  local result_file=""
  local editor_text=""

  result_file="$(worker_line_editor_result_file)"
  : > "$result_file"
  if [[ -e /dev/tty ]]; then
    stty sane < /dev/tty >/dev/tty 2>/dev/null || true
    python3 "$(worker_line_editor_script)" \
      --personality "${PERSONALITY:-WORKER}" \
      --workfile "${WORKING_ON:-}" \
      --draft-path "$AGENIC_PROJECT_PONY_RUNTIME_DRAFT_PATH" \
      --notice-path "$AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_PATH" \
      --history-path "$(worker_line_editor_history_file)" \
      --result-path "$result_file" \
      </dev/tty >/dev/tty 2>/dev/tty || editor_status=$?
  else
    python3 "$(worker_line_editor_script)" \
      --personality "${PERSONALITY:-WORKER}" \
      --workfile "${WORKING_ON:-}" \
      --draft-path "$AGENIC_PROJECT_PONY_RUNTIME_DRAFT_PATH" \
      --notice-path "$AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_PATH" \
      --history-path "$(worker_line_editor_history_file)" \
      --result-path "$result_file" || editor_status=$?
  fi
  if [[ $editor_status -eq 0 ]]; then
    editor_text="$(<"$result_file")"
    worker_resume_codex "$editor_text"
  fi
  rm -f -- "$result_file"
  return $editor_status
}

worker_enter_line_editor_loop() {
  local editor_status=0
  if ! worker_codex_is_stopped; then
    return 0
  fi
  if [[ "$WORKER_EDITOR_LOOP_ACTIVE" -eq 1 ]]; then
    return 0
  fi
  WORKER_EDITOR_LOOP_ACTIVE=1
  while worker_codex_is_stopped; do
    if [[ "$WORKER_EDITOR_ACTIVE" -eq 1 ]]; then
      break
    fi
    WORKER_EDITOR_ACTIVE=1
    worker_runtime_sync_notice
    worker_collect_prompt_input
    editor_status=$?
    WORKER_EDITOR_ACTIVE=0
    case "$editor_status" in
      0) ;;
      130) break ;;
      *)
        echo "Line editor exited with status $editor_status."
        break
        ;;
    esac
  done
  WORKER_EDITOR_LOOP_ACTIVE=0
}

if [[ -n "${WORKER_ROOTDIR:-}" ]]; then
  builtin cd "$WORKER_ROOTDIR" 2>/dev/null || true
fi

TRAPUSR1() {
  WORKER_WAKE_REQUESTED=1
  worker_update_state "wake_requested"
  if [[ -t 1 ]]; then
    print -r -- 'Wake signal received. Codex launch queued.'
  fi
}

launch_codex() {
  local exit_code=0
  local -a codex_args=()
  local -a manual_args=("$@")
  local codex_pid_file=""
  local codex_job_file=""
  if [[ -n "${WORKER_CODEX_PROFILE:-}" ]]; then
    codex_args+=(-p "$WORKER_CODEX_PROFILE")
  fi
  if [[ -n "${INITIAL_PROMPT:-}" ]]; then
    codex_args+=("$INITIAL_PROMPT")
  fi
  if [[ ${#manual_args[@]} -gt 0 ]]; then
    codex_args+=("${manual_args[@]}")
  fi
  WORKER_CODEX_ACTIVE=1
  codex_pid_file="$(worker_runtime_codex_pid_file)"
  codex_job_file="$(worker_runtime_codex_job_file)"
  rm -f -- "$codex_pid_file" "$codex_job_file"
  if [[ ! -t 0 || ! -t 1 ]]; then
    echo 'Codex launch requires an interactive terminal.'
    WORKER_CODEX_ACTIVE=0
    worker_update_state "shell"
    return 1
  fi
  WORKER_CODEX_PID="pending"
  worker_update_state "running_codex"
  if [[ ${#codex_args[@]} -gt 0 ]]; then
    CODEX_PONY_PID_FILE="$codex_pid_file" \
    CODEX_PONY_IDLE_MONITOR_SCRIPT="${WORKER_CODEX_IDLE_MONITOR_SCRIPT:-}" \
    CODEX_PONY_TMUX_SOCKET_PATH="${PONY_TMUX_SOCKET_PATH:-}" \
    CODEX_PONY_IDLE_SENTINEL="${WORKER_IDLE_SENTINEL:-}" \
    CODEX_PONY_PARTIAL_IDLE_SENTINEL="${WORKER_PARTIAL_IDLE_SENTINEL:-Ω}" \
    "${WORKER_CODEX_WRAPPER}" "${codex_args[@]}" || exit_code=$?
  else
    CODEX_PONY_PID_FILE="$codex_pid_file" \
    CODEX_PONY_IDLE_MONITOR_SCRIPT="${WORKER_CODEX_IDLE_MONITOR_SCRIPT:-}" \
    CODEX_PONY_TMUX_SOCKET_PATH="${PONY_TMUX_SOCKET_PATH:-}" \
    CODEX_PONY_IDLE_SENTINEL="${WORKER_IDLE_SENTINEL:-}" \
    CODEX_PONY_PARTIAL_IDLE_SENTINEL="${WORKER_PARTIAL_IDLE_SENTINEL:-Ω}" \
    "${WORKER_CODEX_WRAPPER}" || exit_code=$?
  fi
  WORKER_CODEX_ACTIVE=0
  if [[ -f "$codex_pid_file" ]]; then
    WORKER_CODEX_PID="$(<"$codex_pid_file")"
  fi
  if [[ $exit_code -eq 148 ]]; then
    worker_record_codex_job
    worker_update_state "waiting_user"
    worker_enter_line_editor_loop
    return 0
  fi
  if worker_codex_is_stopped; then
    worker_record_codex_job
    worker_update_state "waiting_user"
    worker_enter_line_editor_loop
    return 0
  fi
  worker_clear_codex_tracking
  worker_state_complete
  worker_update_state "shell"
  if [[ $exit_code -eq 130 ]]; then
    echo 'Codex interrupted. Shell kept open.'
  elif [[ $exit_code -ne 0 ]]; then
    echo "Codex exited with status $exit_code. Shell kept open."
  fi
}

worker_maybe_launch_codex() {
  if [[ "$WORKER_WAKE_REQUESTED" -eq 1 && "$WORKER_CODEX_ACTIVE" -eq 0 ]]; then
    WORKER_WAKE_REQUESTED=0
    echo "Waking up $(worker_display_name) agent."
    launch_codex
  fi
}

add-zsh-hook precmd worker_maybe_launch_codex
add-zsh-hook precmd worker_runtime_sync_notice
add-zsh-hook precmd worker_enter_line_editor_loop

codex-restart() {
  WORKER_WAKE_REQUESTED=1
  worker_update_state "wake_requested"
  echo 'Codex restart queued for next prompt.'
}

codex-pony() {
  if [[ "$WORKER_CODEX_ACTIVE" -eq 1 ]]; then
    echo 'Codex is already running in this shell.'
    return 1
  fi
  launch_codex "$@"
}

worker_accept_line() {
  local current_buffer="$BUFFER"
  if worker_codex_is_stopped; then
    BUFFER=""
    CURSOR=0
    zle reset-prompt
    worker_resume_codex "$current_buffer"
    zle -R
    return 0
  fi
  zle .accept-line
}

dirty_fix_first_prompt() {
  local cleanup_prompt=""
  cleanup_prompt="Coordinator preflight detected a dirty worktree in ${AGENIC_PROJECT_ROOT}. First, inspect and reconcile or put away the pending local changes in that repo. Do not ignore them or defer that cleanup. After the worktree is in a deliberate state, continue with normal Twilight coordination behavior."
  if [[ -n "${INITIAL_PROMPT:-}" ]]; then
    printf '%s\n\n%s\n' "$cleanup_prompt" "$INITIAL_PROMPT"
  else
    printf '%s\n' "$cleanup_prompt"
  fi
}

worker_run_postflight() {
  if [[ "${WORKER_POSTFLIGHT_RAN:-0}" == "1" ]]; then
    return 0
  fi
  export WORKER_POSTFLIGHT_RAN=1
  if [[ -n "${WORKER_POSTFLIGHT_SCRIPT:-}" ]]; then
    "${WORKER_POSTFLIGHT_SCRIPT}" \
      "${PERSONALITY:-}" \
      "${WORKING_ON:-}" \
      "${WORKER_ROOTDIR:-$PWD}" || true
  fi
}

zshexit() {
  worker_run_postflight
  worker_remove_runtime_files
}

worker_update_state "shell"
if [[ -t 0 && -t 1 ]]; then
  setopt MONITOR 2>/dev/null || true
fi
"$(worker_queue_script)" init >/dev/null 2>&1 || true

if [[ -o interactive ]]; then
  zle -N accept-line worker_accept_line
  zle -N zle-line-init worker_runtime_draft_restore
  zle -N zle-line-finish worker_runtime_draft_save
fi

case "${WORKER_PREFLIGHT_RESULT:-}" in
  READY_NO_LLM)
    worker_update_state "parked_ready_no_llm"
    echo 'Preflight: READY_NO_LLM. codex-pony sleeping.'
    ;;
  BLOCKED_DIRTY_FIX_FIRST)
    echo 'Preflight: dirty worktree. Launching Twilight in fix-first mode.'
    if [[ "${PERSONALITY:-}" == 'TWILIGHT_SPARKLE' ]]; then
      export WORKER_CODEX_PROFILE='twi_coordinator'
      export INITIAL_PROMPT="$(dirty_fix_first_prompt)"
      launch_codex
    else
      echo 'Only Twilight may continue from BLOCKED_DIRTY_FIX_FIRST.'
    fi
    ;;
  ESCALATE_MINI)
    export WORKER_CODEX_PROFILE='worker_mini'
    launch_codex
    ;;
  ESCALATE_TWI)
    if [[ "${PERSONALITY:-}" == 'TWILIGHT_SPARKLE' ]]; then
      export WORKER_CODEX_PROFILE='twi_coordinator'
      launch_codex
    else
      echo 'Preflight: ESCALATE_TWI. Worker Codex not launched.'
    fi
    ;;
  *)
    echo "Preflight error: unexpected result '${WORKER_PREFLIGHT_RESULT:-}'."
    ;;
esac

if worker_codex_is_stopped; then
  worker_enter_line_editor_loop
fi

unset WORKER_PREFLIGHT_RESULT
unset WORKER_CODEX_PROFILE
EOF

exec env \
  ZDOTDIR="$zdotdir" \
  AGENIC_PROJECT_ROOT="$AGENIC_PROJECT_ROOT" \
  AGENIC_PROJECT_PONY_BIN_DIR="$AGENIC_PROJECT_PONY_BIN_DIR" \
  AGENIC_PROJECT_PONY_AGENTS_DIR="$AGENIC_PROJECT_PONY_AGENTS_DIR" \
  AGENIC_PROJECT_PONY_SCRIPTS_DIR="$AGENIC_PROJECT_PONY_SCRIPTS_DIR" \
  AGENIC_PROJECT_PONY_RUNTIME_DIR="$AGENIC_PROJECT_PONY_RUNTIME_DIR" \
  AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_PATH="$AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_PATH" \
  AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_SEEN_PATH="$AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_SEEN_PATH" \
  AGENIC_PROJECT_PONY_RUNTIME_ACTIVE_PROMPT_PATH="$AGENIC_PROJECT_PONY_RUNTIME_ACTIVE_PROMPT_PATH" \
  AGENIC_PROJECT_PONY_RUNTIME_DRAFT_PATH="$AGENIC_PROJECT_PONY_RUNTIME_DRAFT_PATH" \
  WORKER_ROOTDIR="$rootdir" \
  PONY_TMUX_SOCKET_PATH="$tmux_socket_path" \
  WORKER_IDLE_SENTINEL="$idle_sentinel" \
  WORKER_PARTIAL_IDLE_SENTINEL="$partial_idle_sentinel" \
  WORKER_CODEX_WRAPPER="$repo_codex_pony" \
  WORKER_CODEX_IDLE_MONITOR_SCRIPT="$monitor_script" \
  WORKER_POSTFLIGHT_SCRIPT="$postflight_script" \
  WORKER_PREFLIGHT_RESULT="$preflight_result" \
  PERSONALITY="$PERSONALITY" \
  WORKING_ON="$WORKING_ON" \
  INITIAL_PROMPT="$INITIAL_PROMPT" \
  zsh -d -i