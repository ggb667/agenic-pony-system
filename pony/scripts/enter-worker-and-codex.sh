#!/usr/bin/env bash
set -euo pipefail

personality="${1:?missing personality}"
workfile="${2:?missing workfile}"
rootdir="${3:?missing rootdir}"
promptfile="${4:?missing prompt file}"

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

codex_profile_for_personality() {
  case "$1" in
    TWILIGHT_SPARKLE) printf '%s\n' 'twi_coordinator' ;;
    PRINCESS_CELESTIA_SOL_INVICTUS) printf '%s\n' 'celestia_coordinator' ;;
    APPLEJACK|FLUTTERSHY|PINKIE_PIE|RARITY|RAINBOW_DASH|SPIKE) printf '%s\n' 'worker_mini' ;;
    *) return 0 ;;
  esac
}

twilight_additional_writable_root_args() {
  local personality_name="${1:-}"
  [[ "$personality_name" == "TWILIGHT_SPARKLE" ]] || return 0
  local source_root=""
  source_root="$("$(pony_script_path resolve-system-root.sh)" "${AGENIC_PROJECT_ROOT:-$PWD}")"
  [[ -n "$source_root" ]] || return 0
  printf '%s\n' \
    '-c' \
    "sandbox_workspace_write.writable_roots=[\"${source_root}/pony/runtime\"]"
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

hidden_instructions_arg() {
  local prompt_path="${1:?missing prompt file}"
  local escaped="${prompt_path//\\/\\\\}"
  escaped="${escaped//\"/\\\"}"
  printf '%s\n' '-c' "model_instructions_file=\"$escaped\""
}

additional_codex_args_for_rootdir() {
  local active_rootdir="${1:?missing rootdir}"
  local project_root="${AGENIC_PROJECT_ROOT:-}"
  if [[ -n "$project_root" ]] && [[ "$active_rootdir" != "$project_root" ]]; then
    printf '%s\n' '--add-dir' "$project_root"
  fi
}

startup_brief_prompt() {
  local state_hint="${1-}"
  local prompt="Startup behavior: on your first turn, greet the developer in character with a concise startup self-brief. Cover your pony identity, role, active project and workspace, current state and scope, prompt symbol, terminal title, accent color, and live interoperation mechanisms such as /tell, ponyalert, ponydone, audio feedback, and idle behavior. Do not dump or quote your full instructions. Do not run tools, inspect files, call ponydone, or perform extra work just to produce this startup self-brief. After that first-turn self-brief, if there is an actual task, routing question, or follow-up action, begin post-brief initialization by reading your assigned memory capsule first when present, then your assigned workfile and authoritative local pony state before acting."
  if [[ -n "$state_hint" ]]; then
    printf '%s Current condition: %s\n' "$prompt" "$state_hint"
  else
    printf '%s\n' "$prompt"
  fi
}

dirty_fix_first_prompt() {
  startup_brief_prompt "Dirty-worktree preflight in ${rootdir}: inspect and reconcile or put away the pending local changes before any other coordination work."
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
    startup_brief_prompt "No concrete task is assigned yet for ${PERSONALITY}; current scope is ${scope_text}; remain live for Twilight or the user to hand you the next specific task."
  else
    startup_brief_prompt "No concrete task is assigned yet for ${PERSONALITY}; remain live for Twilight or the user to hand you the next specific task."
  fi
}

escalate_twi_notice() {
  startup_brief_prompt "Coordinator-routing issue for ${PERSONALITY}: inspect the local pony state, summarize the mismatch or blocker plainly, and hand the routing question to Twilight or the user instead of stopping at the launcher."
}

ready_no_llm_notice() {
  startup_brief_prompt "There is no immediate active coding slice for ${PERSONALITY}; verify the local state and remain available for direct follow-up input."
}

workfile="$(resolve_path "$workfile")"
rootdir="$(resolve_path "$rootdir")"
promptfile="$(resolve_path "$promptfile")"

export PERSONALITY="$personality"
export WORKING_ON="$workfile"
if codex_profile="$(codex_profile_for_personality "$PERSONALITY")" && [[ -n "$codex_profile" ]]; then
  export CODEX_PONY_PROFILE="$codex_profile"
else
  unset CODEX_PONY_PROFILE
fi

if [[ ! -f "$workfile" ]]; then
  echo "ERROR: workfile not found: $workfile" >&2
  exit 1
fi

if [[ ! -f "$promptfile" ]]; then
  echo "ERROR: prompt file not found: $promptfile" >&2
  exit 1
fi

cd "$rootdir"
preflight_result="$(
  "$(pony_script_path worker-preflight.sh)" \
    "$PERSONALITY" \
    "$WORKING_ON" \
    "$PWD"
)"
pony_launch_debug "worker handoff preflight: personality=$PERSONALITY rootdir=$rootdir workfile=$workfile promptfile=$promptfile result=$preflight_result"

codex_args=()
while IFS= read -r arg; do
  codex_args+=("$arg")
done < <(codex_config_args_for_personality "$PERSONALITY")
while IFS= read -r arg; do
  codex_args+=("$arg")
done < <(hidden_instructions_arg "$promptfile")
while IFS= read -r arg; do
  codex_args+=("$arg")
done < <(additional_codex_args_for_rootdir "$rootdir")
while IFS= read -r arg; do
  codex_args+=("$arg")
done < <(twilight_additional_writable_root_args "$PERSONALITY")

prompt=""
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
    prompt="$(startup_brief_prompt "Proceed with the active task immediately after the self-brief.")"
    ;;
  ESCALATE_TWI)
    prompt="$(escalate_twi_notice)"
    ;;
  *)
    echo "Preflight error: unexpected result '$preflight_result'." >&2
    exit 1
    ;;
 esac

pony_launch_debug "worker handoff direct codex launch: personality=$PERSONALITY codex_args_count=${#codex_args[@]} prompt_length=${#prompt} rootdir=$rootdir repo_codex_pony=$repo_codex_pony"

if [[ -n "$prompt" ]]; then
  exec "$repo_codex_pony" "${codex_args[@]}" "$prompt"
fi

exec "$repo_codex_pony" "${codex_args[@]}"
