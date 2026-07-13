#!/usr/bin/env bash
set -euo pipefail

pony_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resolve_agenic_root() {
  local script_dir="${1:?missing script dir}"
  local candidate_root
  local project_wrapper
  local wrapped_bin

  candidate_root="$(cd "$script_dir/../.." && pwd)"
  if [[ -x "$candidate_root/scripts/install-project.sh" ]]; then
    printf '%s\n' "$candidate_root"
    return 0
  fi

  if [[ -n "${AGENIC_PONY_SOURCE_ROOT:-}" ]] && [[ -x "${AGENIC_PONY_SOURCE_ROOT}/scripts/install-project.sh" ]]; then
    cd "$AGENIC_PONY_SOURCE_ROOT" && pwd
    return 0
  fi

  project_wrapper="$candidate_root/pony/bin/codex-pony"
  if [[ -f "$project_wrapper" ]]; then
    wrapped_bin="$(sed -n 's#^exec "\(.*\)/pony/bin/codex-pony" "\$@"$#\1/pony/bin/codex-pony#p' "$project_wrapper" | head -n 1)"
    if [[ -n "$wrapped_bin" ]] && [[ -x "$wrapped_bin" ]]; then
      cd "$(dirname "$wrapped_bin")/../.." && pwd
      return 0
    fi
  fi

  printf '%s\n' "$candidate_root"
}

agenic_root="$(resolve_agenic_root "$pony_script_dir")"
export AGENIC_PONY_SOURCE_ROOT="$agenic_root"
pony_root="$agenic_root/pony"
pony_bin_dir="$pony_root/bin"
pony_scripts_dir="$pony_root/scripts"
pony_launch_prompts_dir="$pony_root/launch.prompts"

detect_project_root() {
  local start_dir="${1:-$PWD}"
  local candidate_root=""
  local config_path=""
  local configured_project_root=""

  if git -C "$start_dir" rev-parse --show-toplevel >/dev/null 2>&1; then
    candidate_root="$(git -C "$start_dir" rev-parse --show-toplevel)"
  else
    candidate_root="$(cd "$start_dir" && pwd)"
  fi

  config_path="$candidate_root/pony/pony.system.config.yaml"
  if [[ -f "$config_path" ]]; then
    configured_project_root="$(awk -F': ' '$1 == "project_root" {print substr($0, index($0, ": ") + 2); exit}' "$config_path")"
    if [[ -n "$configured_project_root" && -d "$configured_project_root" ]]; then
      cd "$configured_project_root" && pwd
      return 0
    fi
  fi

  printf '%s\n' "$candidate_root"
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

project_label() {
  local project_root="${1:?missing project root}"
  local config_path="$project_root/pony/pony.system.config.yaml"
  local configured_name=""
  if [[ -f "$config_path" ]]; then
    configured_name="$(awk -F': ' '$1 == "project_name" {print substr($0, index($0, ": ") + 2); exit}' "$config_path")"
  fi
  if [[ -n "$configured_name" ]]; then
    printf '%s\n' "$configured_name"
    return 0
  fi
  printf '%s\n' "$(basename "$project_root")"
}

project_slug() {
  local project_root="${1:?missing project root}"
  printf '%s' "$(basename "$project_root")" | tr -cs '[:alnum:]._+-' '-' | sed 's/^-*//; s/-*$//'
}

default_launch_env_file() {
  local project_root="${1:?missing project root}"
  local state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
  local slug
  slug="$(project_slug "$project_root")"
  printf '%s\n' "$state_home/agenic-pony-system/projects/$slug/launch.env"
}

worker_slug_for_personality() {
  local personality
  personality="$(printf '%s' "${1:-}" | tr '[:lower:]' '[:upper:]')"
  case "$personality" in
    TIA|CELESTIA|PRINCESS|CELLY|SUNBUTT|PRINCESS_CELESTIA_SOL_INVICTUS) printf 'celestia\n' ;;
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
    celestia) printf 'Princess Celestia Sol Invictus\n' ;;
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
    celestia) printf 'PRINCESS_CELESTIA_SOL_INVICTUS\n' ;;
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

canonical_personality() {
  local input="${1:?missing personality}"
  local slug
  slug="$(worker_slug_for_personality "$input")" || return 1
  worker_personality_for_slug "$slug"
}

workfile_name_for_slug() {
  case "${1:-}" in
    celestia) printf 'governor-celestia.md\n' ;;
    twi) printf 'coordinator-twi.md\n' ;;
    *) printf '%s.md\n' "${1:?missing worker slug}" ;;
  esac
}

worker_branch_for_slug() {
  local slug="${1:?missing worker slug}"
  if [[ "$slug" == "twi" ]]; then
    if [[ "$AGENIC_PROJECT_ROOT" == "$agenic_root" ]]; then
      printf '%s\n' "$AGENIC_PROJECT_BRANCH"
    else
      printf '%s\n' "main"
    fi
    return 0
  fi
  if [[ "$slug" == "celestia" ]]; then
    printf '%s\n' "$AGENIC_PROJECT_BRANCH"
    return 0
  fi
  if [[ "$AGENIC_PROJECT_ROOT" == "$agenic_root" ]]; then
    printf '%s\n' "$AGENIC_PROJECT_BRANCH"
  else
    printf 'pony/%s/main\n' "$slug"
  fi
}

worker_worktree_for_slug() {
  local slug="${1:?missing worker slug}"
  case "$slug" in
    twi|celestia)
      printf '%s\n' "$AGENIC_PROJECT_ROOT"
      ;;
    *)
      printf '%s\n' "$AGENIC_PROJECT_PONY_WORKTREES_DIR/$slug"
      ;;
  esac
}

worker_slug_for_label() {
  case "${1:-}" in
    Princess|Princess\ Celestia|Princess\ Celestia\ Sol\ Invictus) printf 'celestia\n' ;;
    AJ) printf 'aj\n' ;;
    FS) printf 'fs\n' ;;
    Pinkie) printf 'pinkie\n' ;;
    Rarity) printf 'rarity\n' ;;
    RD) printf 'rd\n' ;;
    Spike) printf 'spike\n' ;;
    Twilight) printf 'twi\n' ;;
    *) return 1 ;;
  esac
}

idle_sentinel_for_personality() {
  case "${1:-}" in
    TIA|CELESTIA|PRINCESS|CELLY|SUNBUTT|PRINCESS_CELESTIA_SOL_INVICTUS) printf 'Princess Celestia is tending the sun and awaiting new instructions. Ω\n' ;;
    AJ|APPLEJACK) printf 'Applejack is bucking apples and awaiting new instructions. Ω\n' ;;
    FS|FLUTTERSHY|SHY|FLUTTERS) printf 'Fluttershy is feeding her animals and awaiting new instructions. Ω\n' ;;
    PINKIE|PINKIE_PIE) printf 'Pinkie Pie is planning a party and awaiting new instructions. Ω\n' ;;
    RARITY|RARES) printf 'Rarity is refining a sketch and awaiting new instructions. Ω\n' ;;
    RD|RAINBOW|RAINBOW_DASH|DASH) printf 'Rainbow Dash is practicing new tricks and awaiting new instructions. Ω\n' ;;
    SPIKE) printf 'Spike is sorting scrolls and awaiting new instructions. Ω\n' ;;
    TWI|TWILIGHT|TWILIGHT_SPARKLE) printf 'Twilight Sparkle is reading a book and awaiting new instructions. Ω\n' ;;
    *) return 1 ;;
  esac
}

idle_sentinel_options_for_personality() {
  case "${1:-}" in
    TIA|CELESTIA|PRINCESS|CELLY|SUNBUTT|PRINCESS_CELESTIA_SOL_INVICTUS)
      cat <<'EOF'
Princess Celestia is tending the sun and awaiting new instructions. Ω
Princess Celestia is reviewing the budget, finances and the royal ledgers and awaiting new instructions. Ω
Princess Celestia is reorganizing the royal library and awaiting new instructions. Ω
Princess Celestia is passing judgement and awaiting new instructions. Ω
Princess Celestia is composing memoirs and awaiting new instructions. Ω
Princess Celestia is attending court and awaiting new instructions. Ω
EOF
      ;;
    AJ|APPLEJACK)
      cat <<'EOF'
Applejack is bucking apples and awaiting new instructions. Ω
Applejack is fixing a fence and awaiting new instructions. Ω
Applejack is counting supply crates and awaiting new instructions. Ω
Applejack is sweeping the barn and awaiting new instructions. Ω
Applejack is pretending she is not supervising everypony else and awaiting new instructions. Ω
EOF
      ;;
    FS|FLUTTERSHY|SHY|FLUTTERS)
      cat <<'EOF'
Fluttershy is feeding her animals and awaiting new instructions. Ω
Fluttershy is conducting bird songs and awaiting new instructions. Ω
Fluttershy is tending her garden and awaiting new instructions. Ω
Fluttershy is humming softly and awaiting new instructions. Ω
Fluttershy is wrestling a bear and awaiting new instructions. Ω
EOF
      ;;
    PINKIE|PINKIE_PIE)
      cat <<'EOF'
Pinkie Pie is planning a party and awaiting new instructions. Ω
Pinkie Pie is testing emergency confetti reserves and awaiting new instructions. Ω
Pinkie Pie is reorganizing snack caches and awaiting new instructions. Ω
Pinkie Pie is practicing dramatic gasps and awaiting new instructions. Ω
Pinkie Pie is bouncing in place for operational readiness and awaiting new instructions. Ω
EOF
      ;;
    RARITY|RARES)
      cat <<'EOF'
Rarity is refining a sketch and awaiting new instructions. Ω
Rarity is alphabetizing fabric swatches and awaiting new instructions. Ω
Rarity is polishing gemstones and awaiting new instructions. Ω
Rarity is correcting a tragic color choice and awaiting new instructions. Ω
Rarity is fainting artistically but with purpose and awaiting new instructions. Ω
EOF
      ;;
    RD|RAINBOW|RAINBOW_DASH|DASH)
      cat <<'EOF'
Rainbow Dash is practicing new tricks and awaiting new instructions. Ω
Rainbow Dash is napping on a cloud and awaiting new instructions. Ω
Rainbow Dash is racing wonderbolts and awaiting new instructions. Ω
Rainbow Dash is napping in a tree and awaiting new instructions. Ω
Rainbow Dash is doing laps and awaiting new instructions. Ω
Rainbow Dash is napping in bed and awaiting new instructions. Ω
Rainbow Dash is busting clouds and awaiting new instructions. Ω
Rainbow Dash is carb loading before working out and awaiting new instructions. Ω
Rainbow Dash is helping friends and awaiting new instructions. Ω
Rainbow Dash is sleep flying and awaiting new instructions. Ω
Rainbow Dash is reorganizing the weather schedule and awaiting new instructions. Ω
Rainbow Dash is definitely not showing off and awaiting new instructions. Ω
EOF
      ;;
    SPIKE)
      cat <<'EOF'
Spike is sorting scrolls and awaiting new instructions. Ω
Spike is sharpening quills and awaiting new instructions. Ω
Spike is checking checklists and awaiting new instructions. Ω
Spike is sending letters and awaiting new instructions. Ω
Spike is reporting Twilight's activities to Celestia and awaiting new instructions. Ω
Spike is waiting to be appreciated for keeping Equestria safe and awaiting new instructions. Ω
EOF
      ;;
    TWI|TWILIGHT|TWILIGHT_SPARKLE)
      cat <<'EOF'
Twilight Sparkle is reading a book and awaiting new instructions. Ω
Twilight Sparkle is cross-referencing three other books and awaiting new instructions. Ω
Twilight Sparkle is updating a checklist and awaiting new instructions. Ω
Twilight Sparkle is color-coding a checklist and awaiting new instructions. Ω
Twilight Sparkle is building a better checklist and awaiting new instructions. Ω
Twilight Sparkle is practicing her magic and awaiting new instructions. Ω
Twilight Sparkle is eating a daisy sandwich and awaiting new instructions. Ω
EOF
      ;;
    *)
      return 1
      ;;
  esac
}

partial_idle_sentinel() {
  printf 'Ω\n'
}

load_project_paths() {
  local project_root="${1:-$PWD}"
  project_root="$(detect_project_root "$project_root")"

  export AGENIC_PROJECT_ROOT="$project_root"
  export AGENIC_PROJECT_BRANCH
  AGENIC_PROJECT_BRANCH="$(detect_project_branch "$project_root")"
  export AGENIC_PROJECT_NAME
  AGENIC_PROJECT_NAME="$(project_label "$project_root")"
  export AGENIC_PROJECT_SLUG
  AGENIC_PROJECT_SLUG="$(project_slug "$project_root")"

  export AGENIC_PROJECT_PONY_DIR="$project_root/pony"
  export AGENIC_PROJECT_PONY_AGENTS_DIR="$AGENIC_PROJECT_PONY_DIR/agents"
  export AGENIC_PROJECT_PONY_ASSETS_DIR="$AGENIC_PROJECT_PONY_DIR/assets"
  export AGENIC_PROJECT_PONY_BIN_DIR="$AGENIC_PROJECT_PONY_DIR/bin"
  export AGENIC_PROJECT_PONY_SCRIPTS_DIR="$AGENIC_PROJECT_PONY_DIR/scripts"
  export AGENIC_PROJECT_PONY_VENDOR_DIR="$AGENIC_PROJECT_PONY_DIR/vendor"
  export AGENIC_PROJECT_PONY_LAUNCH_PROMPTS_DIR="$AGENIC_PROJECT_PONY_DIR/launch.prompts"
  export AGENIC_PROJECT_PONY_LAUNCH_CONFIGS_DIR="$AGENIC_PROJECT_PONY_DIR/launch.configs"
  export AGENIC_PROJECT_PONY_TEAM_COORDINATION_DIR="$AGENIC_PROJECT_PONY_DIR/team.coordination"
  export AGENIC_PROJECT_PONY_RUNTIME_DIR="$AGENIC_PROJECT_PONY_DIR/runtime"
  export AGENIC_PROJECT_PONY_WORK_DIR="$AGENIC_PROJECT_PONY_DIR/work"
  export AGENIC_PROJECT_PONY_WORKTREES_DIR="$AGENIC_PROJECT_PONY_DIR/worktrees"
  export AGENIC_PROJECT_PONY_CONFIG_PATH="$AGENIC_PROJECT_PONY_DIR/pony.system.config.yaml"

  export AGENIC_PROJECT_PONY_RUNTIME_QUEUE_DIR="$AGENIC_PROJECT_PONY_RUNTIME_DIR/queue"
  export AGENIC_PROJECT_PONY_RUNTIME_QUEUE_ITEMS_DIR="$AGENIC_PROJECT_PONY_RUNTIME_QUEUE_DIR/items"
  export AGENIC_PROJECT_PONY_RUNTIME_STATE_PATH="$AGENIC_PROJECT_PONY_RUNTIME_DIR/runtime.state"
  export AGENIC_PROJECT_PONY_RUNTIME_DRAFT_PATH="$AGENIC_PROJECT_PONY_RUNTIME_DIR/user.draft"
  export AGENIC_PROJECT_PONY_RUNTIME_ACTIVE_PROMPT_PATH="$AGENIC_PROJECT_PONY_RUNTIME_DIR/active.prompt"
  export AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_PATH="$AGENIC_PROJECT_PONY_RUNTIME_DIR/pending.notice"
  export AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_SEEN_PATH="$AGENIC_PROJECT_PONY_RUNTIME_DIR/pending.notice.seen"
  : "${AGENIC_PONY_CHAT_LOG_PATH:=$AGENIC_PROJECT_PONY_RUNTIME_DIR/pony.chat.jsonl}"
  : "${AGENIC_PONY_REGISTRY_LOG_PATH:=$AGENIC_PROJECT_PONY_RUNTIME_DIR/pony.registry.jsonl}"
  export AGENIC_PONY_CHAT_LOG_PATH
  export AGENIC_PONY_REGISTRY_LOG_PATH

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
    "$AGENIC_PROJECT_PONY_ASSETS_DIR" \
    "$AGENIC_PROJECT_PONY_BIN_DIR" \
    "$AGENIC_PROJECT_PONY_SCRIPTS_DIR" \
    "$AGENIC_PROJECT_PONY_VENDOR_DIR" \
    "$AGENIC_PROJECT_PONY_LAUNCH_PROMPTS_DIR" \
    "$AGENIC_PROJECT_PONY_LAUNCH_CONFIGS_DIR" \
    "$AGENIC_PROJECT_PONY_TEAM_COORDINATION_DIR" \
    "$AGENIC_PROJECT_PONY_RUNTIME_DIR" \
    "$AGENIC_PROJECT_PONY_RUNTIME_QUEUE_DIR" \
    "$AGENIC_PROJECT_PONY_RUNTIME_QUEUE_ITEMS_DIR" \
    "$AGENIC_PROJECT_PONY_WORK_DIR" \
    "$AGENIC_PROJECT_PONY_WORKTREES_DIR"
}

pony_ensure_layout_dirs() {
  while IFS= read -r dir; do
    mkdir -p "$dir"
  done < <(project_pony_dirs)
}

pony_bin_path() {
  local name="${1:?missing pony bin name}"
  printf '%s\n' "$AGENIC_PROJECT_PONY_BIN_DIR/$name"
}

pony_script_path() {
  local name="${1:?missing pony script name}"
  printf '%s\n' "$AGENIC_PROJECT_PONY_SCRIPTS_DIR/$name"
}

pony_launch_prompt_path() {
  local name="${1:?missing pony launch prompt name}"
  printf '%s\n' "$AGENIC_PROJECT_PONY_LAUNCH_PROMPTS_DIR/$name"
}

pony_coordination_path() {
  local name="${1:?missing coordination filename}"
  printf '%s\n' "$AGENIC_TEAM_COORDINATION_DIR/$name"
}

pony_assignment_registry_path() {
  pony_coordination_path "assignment.registry.tsv"
}

pony_worker_status_path() {
  local worker_slug="${1:?missing worker slug}"
  pony_coordination_path "${worker_slug}.status.md"
}

pony_worker_mailbox_path() {
  local worker_slug="${1:?missing worker slug}"
  pony_coordination_path "${worker_slug}.mailbox.md"
}

pony_twi_todo_path() {
  pony_coordination_path "twi.todo.md"
}

pony_twi_decisions_path() {
  pony_coordination_path "twi.decisions.md"
}

pony_twi_event_stream_history_path() {
  pony_coordination_path "twi.event.stream.history.md"
}

pony_twi_pending_approvals_path() {
  pony_coordination_path "twi.pending-approvals.md"
}

pony_twi_review_queue_path() {
  pony_coordination_path "twi.review-queue.md"
}

pony_chat_log_path() {
  printf '%s\n' "$AGENIC_PROJECT_PONY_RUNTIME_DIR/pony.chat.jsonl"
}

pony_registry_log_path() {
  printf '%s\n' "$AGENIC_PROJECT_PONY_RUNTIME_DIR/pony.registry.jsonl"
}

agent_bus_mode() {
  local mode="${AGENIC_AGENT_BUS_MODE:-project}"
  case "$mode" in
    global|project)
      printf '%s\n' "$mode"
      ;;
    *)
      printf '%s\n' "project"
      ;;
  esac
}

global_agent_runtime_dir() {
  local state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
  printf '%s\n' "$state_home/agenic-pony-system/runtime"
}

agent_registry_log_path() {
  if [[ "$(agent_bus_mode)" == "global" ]]; then
    printf '%s\n' "$(global_agent_runtime_dir)/agent.registry.jsonl"
    return 0
  fi
  pony_registry_log_path
}

agent_message_log_path() {
  if [[ "$(agent_bus_mode)" == "global" ]]; then
    printf '%s\n' "$(global_agent_runtime_dir)/agent.messages.jsonl"
    return 0
  fi
  pony_chat_log_path
}

agent_session_config_path() {
  local personality="${1:?missing personality}"
  local slug
  slug="$(worker_slug_for_personality "$personality")"
  printf '%s\n' "$AGENIC_PROJECT_PONY_RUNTIME_DIR/${slug}.agent-session.json"
}

resolve_worker_assignment_by_personality() {
  local personality="${1:?missing personality}"
  local registry_file
  registry_file="$(pony_assignment_registry_path)"
  [[ -f "$registry_file" ]] || return 0

  python3 - "$registry_file" "$personality" <<'PY'
import csv
import sys
from pathlib import Path

registry_path, personality = sys.argv[1:]
rows = list(csv.DictReader(Path(registry_path).open(encoding="utf-8"), delimiter="\t"))
matches = [row for row in rows if row["personality"] == personality]
if len(matches) == 1:
    row = matches[0]
    print("\t".join([row["workfile"], row["worktree"]]))
PY
}

pony_twi_review_needed_path() {
  pony_coordination_path "twi.review-needed"
}

pony_multi_agent_control_path() {
  pony_coordination_path "multi.agent.control.md"
}
