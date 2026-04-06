#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../pony/scripts/pony-paths.sh"

target_root="${1:-$PWD}"
load_project_paths "$target_root"

"$script_dir/bootstrap-project.sh" "$AGENIC_PROJECT_ROOT" >/dev/null

target_dir="${WARP_LAUNCH_CONFIG_DIR:-/mnt/c/Users/$USER/AppData/Roaming/warp/Warp/data/launch_configurations}"
project_slug="$AGENIC_PROJECT_SLUG"
team_target="$target_dir/agenic-pony-team-${project_slug}.yaml"
twi_target="$target_dir/agenic-pony-team-${project_slug}-twi.yaml"

mkdir -p "$target_dir"
python3 "$script_dir/render-warp-launch-config.py" \
  --agenic-root "$agenic_root" \
  --project-root "$AGENIC_PROJECT_ROOT" \
  --mode team >"$team_target"
python3 "$script_dir/render-warp-launch-config.py" \
  --agenic-root "$agenic_root" \
  --project-root "$AGENIC_PROJECT_ROOT" \
  --mode twi >"$twi_target"

cat <<EOF
Installed Warp launch configurations.
- project_root: $AGENIC_PROJECT_ROOT
- branch: $AGENIC_PROJECT_BRANCH
- team_config: $team_target
- twi_config: $twi_target

If Warp was already open, reload or restart it to refresh the launch list.
EOF
