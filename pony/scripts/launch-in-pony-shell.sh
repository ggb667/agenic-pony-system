#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
launch_project_root="$(cd "$script_dir/../.." && pwd)"
source "$script_dir/launch-debug.sh"
source "$script_dir/pony-paths.sh"
raw_personality="${1:?missing personality}"
personality="$(canonical_personality "$raw_personality" 2>/dev/null || printf '%s' "$raw_personality")"

case "$personality" in
  PRINCESS_CELESTIA_SOL_INVICTUS) pony_func="celestia" ;;
  TWILIGHT_SPARKLE) pony_func="twi" ;;
  APPLEJACK) pony_func="aj" ;;
  PINKIE_PIE) pony_func="pinkie" ;;
  FLUTTERSHY) pony_func="shy" ;;
  RARITY) pony_func="rarity" ;;
  RAINBOW_DASH) pony_func="rd" ;;
  SPIKE) pony_func="spike" ;;
  *) pony_func="" ;;
esac

case "$personality" in
  PRINCESS_CELESTIA_SOL_INVICTUS) codex_profile="just_you" ;;
  *) codex_profile="" ;;
esac

export AGENIC_LAUNCH_PERSONALITY="$personality"
export AGENIC_PROJECT_ROOT="$launch_project_root"
export PONY_FUNC="$pony_func"
if [[ -n "$codex_profile" ]]; then
  export CODEX_PONY_PROFILE="$codex_profile"
fi
unset AGENIC_PONY_LAUNCH_DEBUG_LOG
unset AGENIC_PONY_LAUNCH_DEBUG_INITIALIZED
unset AGENIC_PONY_AUTORAN
unset AGENIC_PONY_AUTORAN_DONE
pony_launch_debug_init
pony_launch_debug "launch wrapper start: pwd=$PWD project_root=$launch_project_root personality=$personality pony_func=${pony_func:-none}"

default_env_file="$(default_launch_env_file "$launch_project_root")"
export AGENIC_PONY_DEFAULT_ENV_FILE="$default_env_file"

launcher_home_root="${TMPDIR:-/tmp}/agenic-pony-zdotdir"
launcher_home="$launcher_home_root/${USER:-user}-$(basename "$launch_project_root")-${personality}"
mkdir -p "$launcher_home"

cat >"$launcher_home/.zshrc" <<'EOF'
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
_agenic_pony_log() {
  [[ -n "${AGENIC_PONY_LAUNCH_DEBUG_LOG:-}" ]] || return 0
  printf '%s [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "launcher.zshrc" "$1" >>"${AGENIC_PONY_LAUNCH_DEBUG_LOG}"
}
_agenic_pony_log "shell init start: pwd=$PWD target=${AGENIC_PROJECT_ROOT}"
cd "${AGENIC_PROJECT_ROOT}"
_agenic_pony_log "after cd: pwd=$PWD"
[[ -f ~/.zshrc ]] && source ~/.zshrc || true
_agenic_pony_log "after sourcing ~/.zshrc: pwd=$PWD personality=${PERSONALITY:-unset}"
cd "${AGENIC_PROJECT_ROOT}"
unset PERSONALITY
unset WORKING_ON
export AGENIC_PONY_SKIP_DRAFT_RESTORE_ONCE=1
export PATH="${AGENIC_PROJECT_ROOT}/pony/bin:${PATH}"
_agenic_pony_log "after reasserting project root: pwd=$PWD autoran=${AGENIC_PONY_AUTORAN:-unset}"
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
[[ -f ./pony/scripts/pony.zsh.support.zsh ]] && source ./pony/scripts/pony.zsh.support.zsh || true
_agenic_pony_log "after sourcing pony.zsh.support.zsh: pwd=$PWD personality=${PERSONALITY:-unset}"

_agenic_pony_source_launch_env() {
  local env_file=""

  if [[ -n "${AGENIC_PONY_ENV_FILE:-}" ]]; then
    env_file="${AGENIC_PONY_ENV_FILE}"
  elif [[ -f "${AGENIC_PROJECT_ROOT}/pony/runtime/launch.env" ]]; then
    env_file="${AGENIC_PROJECT_ROOT}/pony/runtime/launch.env"
  elif [[ -f "${AGENIC_PONY_DEFAULT_ENV_FILE:-}" ]]; then
    env_file="${AGENIC_PONY_DEFAULT_ENV_FILE}"
  fi

  [[ -n "$env_file" ]] || return 0
  if [[ ! -f "$env_file" ]]; then
    _agenic_pony_log "launch env file missing: ${env_file}"
    return 0
  fi

  _agenic_pony_log "sourcing launch env file: ${env_file}"
  set -a
  source "$env_file"
  set +a
}

_agenic_pony_source_launch_env
_agenic_pony_log "after launch env load: github_token=$( [[ -n "${GITHUB_PAT_TOKEN:-}" ]] && printf 'present' || printf 'missing' )"

_agenic_pony_apply_identity() {
  if [[ -n "${PONY_FUNC:-}" ]] && whence -w "${PONY_FUNC}" >/dev/null 2>&1; then
    "${PONY_FUNC}"
  else
    export PERSONALITY="${AGENIC_LAUNCH_PERSONALITY:-}"
    if whence -w p10k >/dev/null 2>&1; then
      p10k reload || true
    fi
  fi
}

_agenic_pony_set_terminal_title() {
  [[ -t 1 ]] || return 0

  local pony_label=""
  local pony_scope=""
  local registry_file="${AGENIC_PROJECT_ROOT}/pony/team.coordination/assignment.registry.tsv"
  case "${AGENIC_LAUNCH_PERSONALITY:-}" in
    PRINCESS_CELESTIA_SOL_INVICTUS) pony_label="Celestia" ;;
    TWILIGHT_SPARKLE) pony_label="Twilight" ;;
    APPLEJACK) pony_label="Applejack" ;;
    PINKIE_PIE) pony_label="Pinkie" ;;
    FLUTTERSHY) pony_label="Fluttershy" ;;
    RARITY) pony_label="Rarity" ;;
    RAINBOW_DASH) pony_label="Rainbow Dash" ;;
    SPIKE) pony_label="Spike" ;;
    *) pony_label="Pony" ;;
  esac

  if [[ -f "$registry_file" ]]; then
    pony_scope="$(awk -F '\t' -v personality="${AGENIC_LAUNCH_PERSONALITY:-}" '
      NR > 1 && $3 == personality { print $9; exit }
    ' "$registry_file")"
  fi

  local project_label="${AGENIC_PROJECT_ROOT:t}"
  if [[ -n "$pony_scope" && "$pony_scope" != "Idle" && "$pony_scope" != "idle" && "$pony_scope" != "unassigned" ]]; then
    printf '\033]0;%s · %s\007' "${pony_label}" "${pony_scope}"
  else
    printf '\033]0;%s · %s\007' "${pony_label}" "${project_label}"
  fi
}

_agenic_pony_apply_identity
_agenic_pony_set_terminal_title
_agenic_pony_log "after identity apply: pwd=$PWD personality=${PERSONALITY:-unset}"

_agenic_pony_start_audio_host() {
  local source_root runtime_dir host_script pid_file fifo_path log_path host_pid

  source_root="$(./pony/scripts/resolve-system-root.sh "${AGENIC_PROJECT_ROOT}")"
  export AGENIC_PONY_SOURCE_ROOT="${source_root}"
  runtime_dir="${AGENIC_PROJECT_ROOT}/pony/runtime"
  mkdir -p "$runtime_dir"

  fifo_path="${runtime_dir}/audio.host.fifo"
  pid_file="${runtime_dir}/audio.host.pid"
  log_path="${runtime_dir}/audio.host.log"
  host_script="${source_root}/pony/scripts/pony-audio-host.sh"

  export AGENIC_PONY_AUDIO_HOST_FIFO="$fifo_path"
  export AGENIC_PONY_AUDIO_HOST_PID_FILE="$pid_file"

  if [[ -f "$pid_file" ]]; then
    read -r host_pid <"$pid_file" || host_pid=""
    if [[ -n "$host_pid" ]] && kill -0 "$host_pid" 2>/dev/null; then
      _agenic_pony_log "audio host already running: pid=${host_pid}"
      return 0
    fi
  fi

  rm -f "$pid_file" "$fifo_path"
  _agenic_pony_log "starting audio host: script=${host_script} fifo=${fifo_path}"
  nohup "${host_script}" "${AGENIC_PROJECT_ROOT}" "${fifo_path}" "${pid_file}" </dev/null >>"${log_path}" 2>&1 &
}

_agenic_pony_start_audio_host

if [[ -z "${AGENIC_PONY_AUTORAN:-}" ]]; then
  export AGENIC_PONY_AUTORAN=1
  _agenic_pony_log "autorun start-session: personality=${AGENIC_LAUNCH_PERSONALITY} project=${AGENIC_PROJECT_ROOT}"
  source_root="${AGENIC_PONY_SOURCE_ROOT}"
  _agenic_pony_log "resolved source root: ${source_root}"
  export AGENIC_PONY_SOURCE_ROOT="${source_root}"
  "${source_root}/pony/scripts/start-session.sh" "${AGENIC_LAUNCH_PERSONALITY}" "${AGENIC_PROJECT_ROOT}" </dev/tty >/dev/tty 2>&1
  exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    _agenic_pony_log "start-session exited nonzero: exit_code=${exit_code}"
  else
    _agenic_pony_log "start-session returned normally"
  fi
else
  _agenic_pony_log "autorun skipped: personality=${AGENIC_LAUNCH_PERSONALITY} project=${AGENIC_PROJECT_ROOT} autoran=${AGENIC_PONY_AUTORAN}"
fi
EOF

pony_launch_debug "exec zsh: zdotdir=$launcher_home"
exec env ZDOTDIR="$launcher_home" zsh -i
