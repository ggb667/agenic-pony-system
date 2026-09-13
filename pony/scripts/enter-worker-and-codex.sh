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
  if [[ -n "$path" && ! -e "$path" && "$path" == *"/pony/prompts/"* ]]; then
    local migrated="${path/\/pony\/prompts\//\/pony\/launch.prompts\/}"
    if [[ -e "$migrated" ]]; then
      printf '%s\n' "$migrated"
      return 0
    fi
  fi
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

select_supported_codex_model() {
  local role="${1:?missing role}"
  local requested="${2:?missing requested model}"
  local fallbacks="${3:?missing fallback models}"

  python3 - "$role" "$requested" "$fallbacks" <<'PY'
import json
import os
import sys
from pathlib import Path

role, requested, fallbacks_raw = sys.argv[1:]
fallbacks = [item for item in fallbacks_raw.split() if item]
cache_path = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex") / "models_cache.json"
supported: set[str] = set()
cache_error = ""
try:
    payload = json.loads(cache_path.read_text(encoding="utf-8"))
    for model in payload.get("models", []):
        if not isinstance(model, dict):
            continue
        if not model.get("supported_in_api", True):
            continue
        if model.get("visibility") == "hide":
            continue
        slug = str(model.get("slug", "")).strip()
        if slug:
            supported.add(slug)
except Exception as exc:
    cache_error = str(exc)

selected = requested
reason = ""
if supported:
    if requested not in supported:
        selected = next((candidate for candidate in fallbacks if candidate in supported), requested)
        if selected != requested:
            reason = f"requested model {requested!r} is not in the current Codex model cache"
else:
    selected = fallbacks[0] if fallbacks and requested.startswith("gpt-5.4") else requested
    if selected != requested:
        reason = f"could not verify model support from {cache_path}: {cache_error or 'models cache unavailable'}"

if reason:
    print(
        f"WARNING: {role} requested {requested}; using {selected} instead because {reason}.",
        file=sys.stderr,
    )
print(selected)
PY
}

codex_config_args_for_personality() {
  local model
  case "$1" in
    TWILIGHT_SPARKLE)
      model="$(select_supported_codex_model \
        "TWILIGHT_SPARKLE" \
        "${AGENIC_PONY_TWILIGHT_MODEL:-gpt-5.5}" \
        "${AGENIC_PONY_TWILIGHT_MODEL_FALLBACKS:-gpt-5.6-sol gpt-5.6-terra gpt-5.5 gpt-6-astra}")"
      printf '%s\n' \
        '-c' 'model_provider="openai"' \
        '-c' "model=\"$model\"" \
        '-c' 'model_reasoning_effort="high"' \
        '-a' 'never' \
        '-s' 'workspace-write'
      ;;
    PRINCESS_CELESTIA_SOL_INVICTUS)
      model="$(select_supported_codex_model \
        "PRINCESS_CELESTIA_SOL_INVICTUS" \
        "${AGENIC_PONY_CELESTIA_MODEL:-gpt-5.4}" \
        "${AGENIC_PONY_CELESTIA_MODEL_FALLBACKS:-gpt-5.6-terra gpt-5.6-sol gpt-5.5 gpt-6-astra}")"
      printf '%s\n' \
        '-c' 'model_provider="openai"' \
        '-c' "model=\"$model\"" \
        '-c' 'model_reasoning_effort="medium"' \
        '-a' 'on-request' \
        '-s' 'workspace-write'
      ;;
    *)
      model="$(select_supported_codex_model \
        "$1" \
        "${AGENIC_PONY_WORKER_MODEL:-gpt-5.4-mini}" \
        "${AGENIC_PONY_WORKER_MODEL_FALLBACKS:-gpt-5.6-luna gpt-5.6-terra gpt-5.5 gpt-6-astra}")"
      printf '%s\n' \
        '-c' 'model_provider="openai"' \
        '-c' "model=\"$model\"" \
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
  local prompt="Startup behavior: on your first turn, greet the developer in character with a concise startup self-brief. Cover your pony identity, role, active project and workspace, current state and scope, prompt symbol, terminal title, accent color, and live interoperation mechanisms such as /tell, ponyalert, ponydone, audio feedback, and idle behavior. Do not dump or quote your full instructions. Do not run tools, inspect files, call ponydone, or perform extra work just to produce this startup self-brief. After that first-turn self-brief, if a task, routing question, or follow-up is present, perform read-only orientation: read the assigned memory capsule first when present, then the assigned workfile and authoritative local pony state. Do not begin task execution, alter files, send coordination messages, or remedy a preflight solely because startup context mentions it; report that you are oriented and await an explicit user or Twilight instruction. If the user points out a non-file-changing mistake, correct it immediately instead of asking whether to proceed."
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

codex_command=("$repo_codex_pony" "${codex_args[@]}")
if [[ -n "$prompt" ]]; then
  codex_command+=("$prompt")
fi

transcript_path="$(pony_output_tail_path "$PERSONALITY")"
if command -v script >/dev/null 2>&1 && [[ -t 0 && -t 1 ]]; then
  command_line="$(printf '%q ' "${codex_command[@]}")"
  script -q -e -f -c "$command_line" /dev/null | python3 "$script_dir/output-tail.py" "$transcript_path"
  exit "${PIPESTATUS[0]}"
fi

exec "${codex_command[@]}"
