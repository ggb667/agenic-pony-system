#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../pony/scripts/pony-paths.sh"

target_root="${1:-$PWD}"
load_project_paths "$target_root"

"$script_dir/install-project.sh" "$AGENIC_PROJECT_ROOT" >/dev/null

target_dir="${WARP_LAUNCH_CONFIG_DIR:-/mnt/c/Users/$USER/AppData/Roaming/warp/Warp/data/launch_configurations}"
project_slug="$AGENIC_PROJECT_SLUG"
project_launch_config_dir="$AGENIC_PROJECT_PONY_LAUNCH_CONFIGS_DIR"
team_source="$project_launch_config_dir/${project_slug}.pony.team.yaml"
twi_source="$project_launch_config_dir/${project_slug}.pony.team.twi.yaml"
aj_source="$project_launch_config_dir/${project_slug}.pony.aj.yaml"
team_target="$target_dir/agenic-pony-team-${project_slug}.yaml"
twi_target="$target_dir/agenic-pony-team-${project_slug}-twi.yaml"
aj_target="$target_dir/agenic-pony-aj-${project_slug}.yaml"

mkdir -p "$target_dir" "$project_launch_config_dir"
python3 "$script_dir/render-warp-launch-config.py" \
  --agenic-root "$agenic_root" \
  --project-root "$AGENIC_PROJECT_ROOT" \
  --mode team >"$team_source"
python3 "$script_dir/render-warp-launch-config.py" \
  --agenic-root "$agenic_root" \
  --project-root "$AGENIC_PROJECT_ROOT" \
  --mode twi >"$twi_source"
python3 "$script_dir/render-warp-launch-config.py" \
  --agenic-root "$agenic_root" \
  --project-root "$AGENIC_PROJECT_ROOT" \
  --mode aj >"$aj_source"
cp "$team_source" "$team_target"
cp "$twi_source" "$twi_target"
cp "$aj_source" "$aj_target"
touch "$AGENIC_PROJECT_PONY_WINDOWS_WARP_MARKER"

cat <<EOF
Installed Warp launch configurations.
- project_root: $AGENIC_PROJECT_ROOT
- branch: $AGENIC_PROJECT_BRANCH
- project_launch_config_dir: $project_launch_config_dir
- project_team_config: $team_source
- project_twi_config: $twi_source
- project_aj_config: $aj_source
- team_config: $team_target
- twi_config: $twi_target
- aj_config: $aj_target

If Warp was already open, reload or restart it to refresh the launch list.
EOF
