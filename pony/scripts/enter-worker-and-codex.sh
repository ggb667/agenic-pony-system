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
        "${AGENIC_PONY_TWILIGHT_MODEL:-gpt-5.6-sol}" \
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
        "${AGENIC_PONY_CELESTIA_MODEL:-gpt-5.6-sol}" \
        "${AGENIC_PONY_CELESTIA_MODEL_FALLBACKS:-gpt-5.6-sol gpt-5.6-terra gpt-5.5 gpt-6-astra}")"
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
        "${AGENIC_PONY_WORKER_MODEL:-gpt-5.6-luna}" \
        "${AGENIC_PONY_WORKER_MODEL_FALLBACKS:-gpt-5.6-luna gpt-5.6-terra gpt-5.5 gpt-6-astra}")"
      printf '%s\n' \
        '-c' 'model_provider="openai"' \
        '-c' "model=\"$model\"" \
        '-c' 'model_reasoning_effort="low"' \
        '-a' 'on-request' \
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
  printf '%s\n' "Startup behavior: on your first turn, greet the developer in character with a concise startup self-brief. Cover your pony identity, stable role, active project and workspace, startup phase ORIENTATION_REQUIRED, prompt symbol, terminal title, accent color, and live interoperation mechanisms such as /tell, ponyalert, ponydone, audio feedback, and idle behavior. Do not dump or quote your full instructions. Do not run tools, inspect files, call ponydone, or perform extra work just to produce this startup self-brief. After that first-turn self-brief, perform read-only orientation: read the assigned memory capsule first when present, then the assigned workfile and Twilight-managed authoritative local pony state. Orientation only establishes context; do not begin implementation, alter files, send coordination messages, repair a preflight, deploy, or rerun anything. Historical state never authorizes work merely because it was read. If orientation sources conflict, report the exact sources and conflicting values to Twilight and remain parked. Begin work only after an explicit post-start instruction from the user or Twilight. If the user points out a non-file-changing mistake, correct it immediately instead of asking whether to proceed."
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

case "$preflight_result" in
  READY_NO_LLM|READY_KEEP_LIVE|BLOCKED_DIRTY_FIX_FIRST|ESCALATE_MINI|ESCALATE_TWI)
    ;;
  *)
    echo "Preflight error: unexpected result '$preflight_result'." >&2
    exit 1
    ;;
esac
prompt="$(startup_brief_prompt)"

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
