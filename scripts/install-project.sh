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

install_lock_dir="$resolved_target_root/pony/runtime/install-project.lock"
install_lock_info_file="$install_lock_dir/owner"
install_lock_owned_here=0

cleanup_install_lock() {
  if (( install_lock_owned_here )); then
    rm -f "$install_lock_info_file" 2>/dev/null || true
    rmdir "$install_lock_dir" 2>/dev/null || true
  fi
}

if [[ "${AGENIC_PONY_INSTALL_LOCK_HELD:-0}" != "1" ]]; then
  mkdir -p "$(dirname "$install_lock_dir")"
  while ! mkdir "$install_lock_dir" 2>/dev/null; do
    sleep 0.1
  done
  cat >"$install_lock_info_file" <<EOF
pid=$$
started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
project_root=$resolved_target_root
source=fresh-install-project
EOF
  install_lock_owned_here=1
  trap cleanup_install_lock EXIT
fi

"$script_dir/bootstrap-project.sh" "$resolved_target_root"
cleanup_install_lock
trap - EXIT
