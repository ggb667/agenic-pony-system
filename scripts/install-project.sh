#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
agenic_root="$(cd "$script_dir/.." && pwd)"
target_root="${1:-$PWD}"
resolved_target_root="$(cd "$target_root" && pwd)"
existing_pony_root="$resolved_target_root/pony"

if [[ "$resolved_target_root" == "$agenic_root" ]]; then
  exit 0
fi

if [[ -f "$existing_pony_root/pony.system.config.yaml" ]] && [[ -d "$existing_pony_root/scripts" ]]; then
  exit 0
fi

"$script_dir/bootstrap-project.sh" "$resolved_target_root"
