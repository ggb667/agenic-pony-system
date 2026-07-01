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

codex_config_args_for_personality() {
  case "$1" in
    TWILIGHT_SPARKLE)
      printf '%s\n' \
        '-c' 'model_provider="openai"' \
        '-c' 'model="gpt-5.5"' \
        '-c' 'model_reasoning_effort="high"' \
        '-a' 'never' \
        '-s' 'workspace-write'
      ;;
    PRINCESS_CELESTIA_SOL_INVICTUS)
      printf '%s\n' \
        '-c' 'model_provider="openai"' \
        '-c' 'model="gpt-5.4"' \
        '-c' 'model_reasoning_effort="medium"' \
        '-a' 'on-request' \
        '-s' 'workspace-write'
      ;;
    *)
      printf '%s\n' \
        '-c' 'model_provider="openai"' \
        '-c' 'model="gpt-5.4-mini"' \
        '-c' 'model_reasoning_effort="low"' \
        '-a' 'never' \
        '-s' 'workspace-write'
      ;;
  esac
}

additional_codex_args_for_rootdir() {
  local active_rootdir="${1:?missing rootdir}"
  local project_root="${AGENIC_PROJECT_ROOT:-}"
  if [[ -n "$project_root" ]] && [[ "$active_rootdir" != "$project_root" ]]; then
    printf '%s\n' '--add-dir' "$project_root"
  fi
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

escalate_twi_notice() {
  local notice=""
  notice="Preflight detected a coordinator-routing issue for ${PERSONALITY}. Launch Codex anyway, inspect the local pony state, summarize the mismatch or blocker plainly, and hand the routing question to Twilight or the user instead of stopping at the launcher."
  if [[ -n "$initial_prompt" ]]; then
    printf '%s\n\n%s\n' "$notice" "$initial_prompt"
  else
    printf '%s\n' "$notice"
  fi
}

ready_no_llm_notice() {
  local notice=""
  notice="Preflight says there is no immediate active coding slice for ${PERSONALITY}. Launch Codex anyway, verify the local state, and remain available for direct follow-up input rather than stopping at the launcher."
  if [[ -n "$initial_prompt" ]]; then
    printf '%s\n\n%s\n' "$notice" "$initial_prompt"
  else
    printf '%s\n' "$notice"
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

codex_args=()
while IFS= read -r arg; do
  codex_args+=("$arg")
done < <(codex_config_args_for_personality "$PERSONALITY")
while IFS= read -r arg; do
  codex_args+=("$arg")
done < <(additional_codex_args_for_rootdir "$rootdir")
prompt="$initial_prompt"

case "$preflight_result" in
  READY_NO_LLM)
    prompt="$(ready_no_llm_notice)"
    ;;
  READY_KEEP_LIVE)
    prompt="$(waiting_for_task_notice)"
    ;;
  BLOCKED_DIRTY_FIX_FIRST)
    prompt="$(dirty_fix_first_prompt)"
    ;;
  ESCALATE_MINI)
    ;;
  ESCALATE_TWI)
    prompt="$(escalate_twi_notice)"
    ;;
  *)
    echo "Preflight error: unexpected result '$preflight_result'."
    exit 1
    ;;
esac

pony_launch_debug "worker handoff launch selection: personality=$PERSONALITY codex_args_count=${#codex_args[@]} prompt_length=${#prompt} rootdir=$rootdir repo_codex_pony=$repo_codex_pony"

if (( ${#codex_args[@]} > 0 )); then
  if [[ -n "$prompt" ]]; then
    pony_launch_debug "exec codex with explicit config args and prompt"
    exec "$repo_codex_pony" "${codex_args[@]}" "$prompt"
  fi
  pony_launch_debug "exec codex with explicit config args only"
  exec "$repo_codex_pony" "${codex_args[@]}"
fi

if [[ -n "$prompt" ]]; then
  pony_launch_debug "exec codex with prompt only"
  exec "$repo_codex_pony" "$prompt"
fi

pony_launch_debug "exec codex with no prompt and no profile override"
exec "$repo_codex_pony"
