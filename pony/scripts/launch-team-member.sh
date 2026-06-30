#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/pony-paths.sh"
raw_personality="${1:?missing personality}"
personality="$(canonical_personality "$raw_personality" 2>/dev/null || printf '%s' "$raw_personality")"
project_root="$(cd "$script_dir/../.." && pwd)"

"$script_dir/prepare-team-launch.sh" "$project_root"
exec "$script_dir/launch-in-pony-shell.sh" "$personality"
