#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
agenic_root="$(cd "$script_dir/.." && pwd)"
source "$agenic_root/pony/scripts/pony-paths.sh"
target_root="${1:-$PWD}"
resolved_target_root="$(detect_project_root "$target_root")"

if [[ "$resolved_target_root" == "$agenic_root" ]]; then
  exit 0
fi

"$script_dir/bootstrap-project.sh" "$resolved_target_root"
