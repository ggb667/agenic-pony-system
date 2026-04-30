#!/usr/bin/env bash
set -euo pipefail

personality="${1:?missing personality}"
workfile="${2:?missing workfile}"
rootdir="${3:?missing rootdir}"
initial_prompt="${4-}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/launch-debug.sh"
source "$script_dir/pony-paths.sh"
load_project_paths "$(cd "$script_dir/../.." && pwd)"
repo_codex_pony="$(pony_bin_path codex-pony)"
pony_launch_debug_init

resolve_path() {
  local path="${1:-}"
  printf '%s\n' "$path"
}

dirty_fix_first_prompt() {
  local cleanup_prompt=""
  cleanup_prompt="Coordinator preflight detected a dirty worktree in ${rootdir}. First, inspect and reconcile or put away the pending local changes in that repo. Do not ignore them or defer that cleanup. After the worktree is in a deliberate state, continue with normal coordination behavior for the active pony."
  if [[ -n "$initial_prompt" ]]; then
    printf '%s\n\n%s\n' "$cleanup_prompt" "$initial_prompt"
  else
    printf '%s\n' "$cleanup_prompt"
  fi
}

waiting_for_task_notice() {
  local scope_text=""
  scope_text="$(awk '
    index($0, "Scope:") == 1 {
      sub("^Scope: ?", "", $0)
      print
      exit
    }
  ' "$workfile")"
  if [[ -n "$scope_text" && "$scope_text" != "unassigned" ]]; then
    printf 'Preflight: no concrete task is assigned yet for %s. Scope is %s. Remain live at the Codex prompt and wait for Twilight or the user to hand you the next specific task.\n' "$PERSONALITY" "$scope_text"
  else
    printf 'Preflight: no concrete task is assigned yet for %s. Remain live at the Codex prompt and wait for Twilight or the user to hand you the next specific task.\n' "$PERSONALITY"
  fi
}

workfile="$(resolve_path "$workfile")"
rootdir="$(resolve_path "$rootdir")"

export PERSONALITY="$personality"
export WORKING_ON="$workfile"

if [[ ! -f "$workfile" ]]; then
  echo "ERROR: workfile not found: $workfile" >&2
  exit 1
fi

cd "$rootdir"
preflight_result="$(
  "$(pony_script_path worker-preflight.sh)" \
    "$PERSONALITY" \
    "$WORKING_ON" \
    "$PWD"
)"
pony_launch_debug "worker handoff preflight: personality=$PERSONALITY rootdir=$rootdir workfile=$workfile result=$preflight_result"

profile=""
prompt="$initial_prompt"

case "$preflight_result" in
  READY_NO_LLM)
    profile=""
    ;;
  READY_KEEP_LIVE)
    profile='worker_mini'
    prompt=""
    printf '%s\n' "$(waiting_for_task_notice)"
    ;;
  BLOCKED_DIRTY_FIX_FIRST)
    if [[ "$PERSONALITY" == 'TWILIGHT_SPARKLE' ]]; then
      profile='twi_coordinator'
      prompt="$(dirty_fix_first_prompt)"
    elif [[ "$PERSONALITY" == 'PRINCESS_CELESTIA_SOL_INVICTUS' ]]; then
      profile='celestia_coordinator'
      prompt="$(dirty_fix_first_prompt)"
    else
      echo 'Only Twilight may continue from BLOCKED_DIRTY_FIX_FIRST.'
      exit 0
    fi
    ;;
  ESCALATE_MINI)
    profile='worker_mini'
    ;;
  ESCALATE_TWI)
    if [[ "$PERSONALITY" == 'TWILIGHT_SPARKLE' ]]; then
      profile='twi_coordinator'
    elif [[ "$PERSONALITY" == 'PRINCESS_CELESTIA_SOL_INVICTUS' ]]; then
      profile='celestia_coordinator'
    else
      echo 'Preflight: ESCALATE_TWI. Worker Codex not launched.'
      exit 0
    fi
    ;;
  *)
    echo "Preflight error: unexpected result '$preflight_result'."
    exit 1
    ;;
esac

pony_launch_debug "worker handoff launch selection: personality=$PERSONALITY profile=${profile:-none} prompt_length=${#prompt} rootdir=$rootdir repo_codex_pony=$repo_codex_pony"

if [[ -n "$profile" ]]; then
  if [[ -n "$prompt" ]]; then
    pony_launch_debug "exec codex with profile and prompt: profile=$profile"
    exec "$repo_codex_pony" -p "$profile" "$prompt"
  fi
  pony_launch_debug "exec codex with profile only: profile=$profile"
  exec "$repo_codex_pony" -p "$profile"
fi

if [[ -n "$prompt" ]]; then
  pony_launch_debug "exec codex with prompt only"
  exec "$repo_codex_pony" "$prompt"
fi

pony_launch_debug "exec codex with no prompt and no profile override"
exec "$repo_codex_pony"
