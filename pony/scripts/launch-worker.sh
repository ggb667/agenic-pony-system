#!/usr/bin/env bash
set -euo pipefail

personality="${1:?missing personality}"
workfile="${2:?missing workfile}"
initial_prompt="${3-}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/pony-paths.sh"
load_project_paths "$(cd "$script_dir/../.." && pwd)"
repo_codex_pony="$(pony_bin_path codex-pony)"

export PERSONALITY="$personality"
export WORKING_ON="$workfile"

echo "PERSONALITY=$PERSONALITY"
echo "WORKING_ON=$WORKING_ON"
pwd

codex_command=("$repo_codex_pony")
if [[ -n "$initial_prompt" ]]; then
  echo "INITIAL_PROMPT=provided"
  codex_command+=("$initial_prompt")
fi

transcript_path="$(pony_output_tail_path "$PERSONALITY")"
if command -v script >/dev/null 2>&1 && [[ -t 0 && -t 1 ]]; then
  command_line="$(printf '%q ' "${codex_command[@]}")"
  script -q -e -f -c "$command_line" /dev/null | python3 "$script_dir/output-tail.py" "$transcript_path"
  exit "${PIPESTATUS[0]}"
fi

exec "${codex_command[@]}"
