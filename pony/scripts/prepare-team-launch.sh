#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/pony-paths.sh"

project_root="${1:-$PWD}"
load_project_paths "$project_root"
pony_ensure_layout_dirs

lock_dir="$AGENIC_PROJECT_PONY_RUNTIME_DIR/team-launch.prepare.lock"
stamp_file="$AGENIC_PROJECT_PONY_RUNTIME_DIR/team-launch.prepared-at"
window_seconds="${AGENIC_PONY_TEAM_LAUNCH_WINDOW_SECONDS:-5}"
now_epoch="$(date +%s)"
last_epoch="0"

cleanup_lock() {
  rmdir "$lock_dir" 2>/dev/null || true
}

if mkdir "$lock_dir" 2>/dev/null; then
  trap cleanup_lock EXIT
  if [[ -f "$stamp_file" ]]; then
    read -r last_epoch <"$stamp_file" || last_epoch="0"
  fi
  if ! [[ "$last_epoch" =~ ^[0-9]+$ ]]; then
    last_epoch="0"
  fi
  if (( now_epoch - last_epoch > window_seconds )); then
    rm -f "$AGENIC_PROJECT_PONY_AGENTS_DIR"/*.launch.log
    printf '%s\n' "$now_epoch" >"$stamp_file"
  fi
fi
