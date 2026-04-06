#!/usr/bin/env bash
set -euo pipefail

pony_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
agenic_root="$(cd "$pony_script_dir/../.." && pwd)"
pony_root="$agenic_root/pony"
pony_bin_dir="$pony_root/bin"
pony_scripts_dir="$pony_root/scripts"
pony_launch_prompts_dir="$pony_root/launch.prompts"

detect_project_root() {
  local start_dir="${1:-$PWD}"
  if git -C "$start_dir" rev-parse --show-toplevel >/dev/null 2>&1; then
    git -C "$start_dir" rev-parse --show-toplevel
  else
    cd "$start_dir" && pwd
  fi
}

detect_project_branch() {
  local project_root="${1:?missing project root}"
  local branch=""
  if branch="$(git -C "$project_root" symbolic-ref --quiet --short HEAD 2>/dev/null)"; then
    printf '%s\n' "$branch"
    return 0
  fi
  if branch="$(git -C "$project_root" rev-parse --short HEAD 2>/dev/null)"; then
    printf 'detached-%s\n' "$branch"
    return 0
  fi
  printf 'no-git-branch\n'
}

project_slug() {
  local project_root="${1:?missing project root}"
  printf '%s' "$(basename "$project_root")" | tr -cs '[:alnum:]._+-' '-' | sed 's/^-*//; s/-*$//'
}

worker_slug_for_personality() {
  case "${1:-}" in
    AJ|APPLEJACK) printf 'aj\n' ;;
    FS|FLUTTERSHY|SHY|FLUTTERS) printf 'fs\n' ;;
    PINKIE|PINKIE_PIE) printf 'pinkie\n' ;;
    RARITY|RARES) printf 'rarity\n' ;;
    RD|RAINBOW|RAINBOW_DASH|DASH) printf 'rd\n' ;;
    SPIKE) printf 'spike\n' ;;
    TWI|TWILIGHT|TWILIGHT_SPARKLE) printf 'twi\n' ;;
    *) return 1 ;;
  esac
}

worker_label_for_slug() {
  case "${1:-}" in
    aj) printf 'AJ\n' ;;
    fs) printf 'FS\n' ;;
    pinkie) printf 'Pinkie\n' ;;
    rarity) printf 'Rarity\n' ;;
    rd) printf 'RD\n' ;;
    spike) printf 'Spike\n' ;;
    twi) printf 'Twilight\n' ;;
    *) return 1 ;;
  esac
}

worker_personality_for_slug() {
  case "${1:-}" in
    aj) printf 'APPLEJACK\n' ;;
    fs) printf 'FLUTTERSHY\n' ;;
    pinkie) printf 'PINKIE_PIE\n' ;;
    rarity) printf 'RARITY\n' ;;
    rd) printf 'RAINBOW_DASH\n' ;;
    spike) printf 'SPIKE\n' ;;
    twi) printf 'TWILIGHT_SPARKLE\n' ;;
    *) return 1 ;;
  esac
}

workfile_name_for_slug() {
  case "${1:-}" in
    twi) printf 'coordinator-twi.md\n' ;;
    *) printf '%s.md\n' "${1:?missing worker slug}" ;;
  esac
}

load_project_paths() {
  local project_root="${1:-$PWD}"
  project_root="$(detect_project_root "$project_root")"

  export AGENIC_PROJECT_ROOT="$project_root"
  export AGENIC_PROJECT_BRANCH
  AGENIC_PROJECT_BRANCH="$(detect_project_branch "$project_root")"
  export AGENIC_PROJECT_NAME
  AGENIC_PROJECT_NAME="$(basename "$project_root")"
  export AGENIC_PROJECT_SLUG
  AGENIC_PROJECT_SLUG="$(project_slug "$project_root")"

  export AGENIC_PROJECT_PONY_DIR="$project_root/pony"
  export AGENIC_PROJECT_PONY_AGENTS_DIR="$AGENIC_PROJECT_PONY_DIR/agents"
  export AGENIC_PROJECT_PONY_BIN_DIR="$AGENIC_PROJECT_PONY_DIR/bin"
  export AGENIC_PROJECT_PONY_SCRIPTS_DIR="$AGENIC_PROJECT_PONY_DIR/scripts"
  export AGENIC_PROJECT_PONY_LAUNCH_PROMPTS_DIR="$AGENIC_PROJECT_PONY_DIR/launch.prompts"
  export AGENIC_PROJECT_PONY_LAUNCH_CONFIGS_DIR="$AGENIC_PROJECT_PONY_DIR/launch.configs"
  export AGENIC_PROJECT_PONY_TEAM_COORDINATION_DIR="$AGENIC_PROJECT_PONY_DIR/team.coordination"
  export AGENIC_PROJECT_PONY_WORK_DIR="$AGENIC_PROJECT_PONY_DIR/work"
  export AGENIC_PROJECT_PONY_WORKTREES_DIR="$AGENIC_PROJECT_PONY_DIR/worktrees"
  export AGENIC_PROJECT_PONY_CONFIG_PATH="$AGENIC_PROJECT_PONY_DIR/pony.system.config.yaml"

  export AGENIC_PROJECT_PONY_WINDOWS_WARP_MARKER="$AGENIC_PROJECT_PONY_DIR/pony.system.configured.windows.warp"
  export AGENIC_PROJECT_PONY_LINUX_SHELL_MARKER="$AGENIC_PROJECT_PONY_DIR/pony.system.configured.linux.shell"
  export AGENIC_PROJECT_PONY_MACOS_SHELL_MARKER="$AGENIC_PROJECT_PONY_DIR/pony.system.configured.macos.shell"

  export AGENIC_AGENT_WORK_DIR="$AGENIC_PROJECT_PONY_WORK_DIR"
  export AGENIC_TEAM_COORDINATION_DIR="$AGENIC_PROJECT_PONY_TEAM_COORDINATION_DIR"
}

project_pony_dirs() {
  printf '%s\n' \
    "$AGENIC_PROJECT_PONY_DIR" \
    "$AGENIC_PROJECT_PONY_AGENTS_DIR" \
    "$AGENIC_PROJECT_PONY_BIN_DIR" \
    "$AGENIC_PROJECT_PONY_SCRIPTS_DIR" \
    "$AGENIC_PROJECT_PONY_LAUNCH_PROMPTS_DIR" \
    "$AGENIC_PROJECT_PONY_LAUNCH_CONFIGS_DIR" \
    "$AGENIC_PROJECT_PONY_TEAM_COORDINATION_DIR" \
    "$AGENIC_PROJECT_PONY_WORK_DIR" \
    "$AGENIC_PROJECT_PONY_WORKTREES_DIR"
}
