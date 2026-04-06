#!/usr/bin/env bash
set -euo pipefail

personality="${1:?missing personality}"
project_hint="${2:-$PWD}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
agenic_root="$(cd "$script_dir/../.." && pwd)"
source "$script_dir/pony-paths.sh"

"$agenic_root/scripts/install-project.sh" "$project_hint" >/dev/null
load_project_paths "$project_hint"

worker_slug="$(worker_slug_for_personality "$personality")"
workfile="$AGENIC_PROJECT_PONY_WORK_DIR/$(workfile_name_for_slug "$worker_slug")"
promptfile="$AGENIC_PROJECT_PONY_LAUNCH_PROMPTS_DIR/${worker_slug}.txt"

if [[ ! -f "$promptfile" ]]; then
  echo "ERROR: prompt file not found: $promptfile" >&2
  exit 1
fi

runtime_prompt="$(cat "$promptfile")"
runtime_prompt+=$'\n\n'
runtime_prompt+="Project root: $AGENIC_PROJECT_ROOT"$'\n'
runtime_prompt+="Project branch: $AGENIC_PROJECT_BRANCH"$'\n'
runtime_prompt+="Project-local coordination root: $AGENIC_TEAM_COORDINATION_DIR"$'\n'
runtime_prompt+="Project-local pony root: $AGENIC_PROJECT_PONY_DIR"$'\n'
runtime_prompt+="Assigned workfile: $workfile"$'\n'
runtime_prompt+="Blank-state rule: treat this as a fresh project unless the project-local files say otherwise."$'\n'
runtime_prompt+="Installed launcher markers live under: $AGENIC_PROJECT_PONY_DIR"

export PERSONALITY="$personality"
export WORKING_ON="$workfile"
export AGENIC_PROJECT_ROOT
export AGENIC_PROJECT_BRANCH
export AGENIC_TEAM_COORDINATION_DIR
export AGENIC_PROJECT_PONY_DIR

exec "$agenic_root/pony/bin/codex-pony" "$runtime_prompt"
