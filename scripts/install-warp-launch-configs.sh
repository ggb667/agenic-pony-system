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
celestia_source="$project_launch_config_dir/${project_slug}.pony.celestia.yaml"
team_target="$target_dir/agenic-pony-team-${project_slug}.yaml"
twi_target="$target_dir/agenic-pony-team-${project_slug}-twi.yaml"
aj_target="$target_dir/agenic-pony-aj-${project_slug}.yaml"
celestia_target="$target_dir/agenic-pony-celestia-${project_slug}.yaml"
install_team=true
install_aj=true
install_twi=true
install_celestia=false

if [[ "$AGENIC_PROJECT_ROOT" == "$agenic_root" ]]; then
  install_team=false
  install_aj=false
  install_twi=false
  install_celestia=true
fi

mkdir -p "$target_dir" "$project_launch_config_dir"
if [[ "$install_twi" == true ]]; then
  python3 "$script_dir/render-warp-launch-config.py" \
    --agenic-root "$agenic_root" \
    --project-root "$AGENIC_PROJECT_ROOT" \
    --mode twi >"$twi_source"
  cp "$twi_source" "$twi_target"
else
  rm -f "$twi_source" "$twi_target"
fi
if [[ "$install_team" == true ]]; then
  python3 "$script_dir/render-warp-launch-config.py" \
    --agenic-root "$agenic_root" \
    --project-root "$AGENIC_PROJECT_ROOT" \
    --mode team >"$team_source"
  cp "$team_source" "$team_target"
else
  rm -f "$team_source" "$team_target"
fi
if [[ "$install_aj" == true ]]; then
  python3 "$script_dir/render-warp-launch-config.py" \
    --agenic-root "$agenic_root" \
    --project-root "$AGENIC_PROJECT_ROOT" \
    --mode aj >"$aj_source"
  cp "$aj_source" "$aj_target"
else
  rm -f "$aj_source" "$aj_target"
fi
if [[ "$install_celestia" == true ]]; then
  python3 "$script_dir/render-warp-launch-config.py" \
    --agenic-root "$agenic_root" \
    --project-root "$AGENIC_PROJECT_ROOT" \
    --mode celestia >"$celestia_source"
  cp "$celestia_source" "$celestia_target"
else
  rm -f "$celestia_source" "$celestia_target"
fi
touch "$AGENIC_PROJECT_PONY_WINDOWS_WARP_MARKER"

cat <<EOF
Installed Warp launch configurations.
- project_root: $AGENIC_PROJECT_ROOT
- branch: $AGENIC_PROJECT_BRANCH
- project_launch_config_dir: $project_launch_config_dir
$(if [[ "$install_twi" == true ]]; then
  printf '%s\n' "- project_twi_config: $twi_source"
  printf '%s\n' "- twi_config: $twi_target"
fi)
$(if [[ "$install_team" == true ]]; then
  printf '%s\n' "- project_team_config: $team_source"
  printf '%s\n' "- team_config: $team_target"
fi)
$(if [[ "$install_aj" == true ]]; then
  printf '%s\n' "- project_aj_config: $aj_source"
  printf '%s\n' "- aj_config: $aj_target"
fi)
$(if [[ "$install_celestia" == true ]]; then
  printf '%s\n' "- project_celestia_config: $celestia_source"
  printf '%s\n' "- celestia_config: $celestia_target"
fi)

If Warp was already open, reload or restart it to refresh the launch list.
EOF
