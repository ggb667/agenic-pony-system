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
runtime_promptfile="$AGENIC_PROJECT_PONY_RUNTIME_DIR/${worker_slug}.launch.prompt.txt"
idle_sentinel="$(idle_sentinel_for_personality "$personality" || true)"
partial_idle="$(partial_idle_sentinel)"

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
if [[ "$AGENIC_PROJECT_ROOT" == "$agenic_root" ]]; then
  runtime_prompt+="Current-state rule: this project has active coordinator state under pony/team.coordination; resume from it instead of treating the repo as blank."$'\n'
else
  runtime_prompt+="Blank-state rule: treat this as a fresh project unless the project-local files say otherwise."$'\n'
  runtime_prompt+="Target-project rule: you are operating inside $AGENIC_PROJECT_ROOT. Treat this target project's pony/team.coordination, pony/work, and project files as the live coordination and implementation surface."$'\n'
  runtime_prompt+="Do not read from, write to, or coordinate against $agenic_root unless the user explicitly assigns work in the agenic system repo."$'\n'
fi
runtime_prompt+="Installed launcher markers live under: $AGENIC_PROJECT_PONY_DIR"
runtime_prompt+=$'\n\n'
if [[ "$personality" == "TWILIGHT_SPARKLE" ]]; then
  runtime_prompt+="Address rule: address the user as \`Mister\`, \`Sir\`, or \`Commander\`."$'\n\n'
fi
runtime_prompt+="Idle-sentinel rule:"$'\n'
runtime_prompt+="- At a partial idle stopping point, where more work could continue later but no required user answer is pending, end your response with exactly this line and nothing after it:"$'\n'
runtime_prompt+="  $partial_idle"$'\n'
runtime_prompt+="- At a full idle stopping point, where you are genuinely awaiting a new prompt, end your response with exactly this line and nothing after it:"$'\n'
runtime_prompt+="  $idle_sentinel"$'\n'
runtime_prompt+="- Do not emit either idle marker after required questions, approvals, escalations, or any response that still needs immediate user input."
printf '%s\n' "$runtime_prompt" >"$runtime_promptfile"

if [[ "$personality" == "TWILIGHT_SPARKLE" ]]; then
  exec "$AGENIC_PROJECT_PONY_SCRIPTS_DIR/enter-twi-session.sh" "$runtime_promptfile"
fi

exec "$AGENIC_PROJECT_PONY_SCRIPTS_DIR/enter-worker-from-prompt-file.sh" \
  "$personality" \
  "$workfile" \
  "$AGENIC_PROJECT_ROOT" \
  "$runtime_promptfile"