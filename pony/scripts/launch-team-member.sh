#!/usr/bin/env bash
set -euo pipefail

personality="${1:?missing personality}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/../.." && pwd)"

"$script_dir/prepare-team-launch.sh" "$project_root"
exec "$script_dir/launch-in-pony-shell.sh" "$personality"
