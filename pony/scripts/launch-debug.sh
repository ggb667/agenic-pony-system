#!/usr/bin/env bash
set -euo pipefail

pony_launch_debug_enabled() {
  return 0
}

pony_launch_debug_slug() {
  case "${AGENIC_LAUNCH_PERSONALITY:-${PERSONALITY:-unknown}}" in
    PRINCESS_CELESTIA_SOL_INVICTUS) printf 'celestia' ;;
    TWILIGHT_SPARKLE) printf 'twi' ;;
    APPLEJACK) printf 'aj' ;;
    PINKIE_PIE) printf 'pinkie' ;;
    FLUTTERSHY) printf 'fs' ;;
    RARITY) printf 'rarity' ;;
    RAINBOW_DASH) printf 'rd' ;;
    SPIKE) printf 'spike' ;;
    *)
      printf '%s' "${AGENIC_LAUNCH_PERSONALITY:-${PERSONALITY:-unknown}}" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]._-' '-'
      ;;
  esac
}

pony_launch_debug_path() {
  local project_root="${AGENIC_PROJECT_ROOT:-}"
  local slug
  slug="$(pony_launch_debug_slug)"

  if [[ -n "$project_root" ]]; then
    printf '%s\n' "$project_root/pony/agents/${slug}.launch.log"
    return 0
  fi

  printf '%s\n' "${TMPDIR:-/tmp}/agenic-pony-launch-${slug}.log"
}

pony_launch_debug_init() {
  pony_launch_debug_enabled || return 0

  if [[ "${AGENIC_PONY_LAUNCH_DEBUG_INITIALIZED:-0}" == "1" ]] && [[ -n "${AGENIC_PONY_LAUNCH_DEBUG_LOG:-}" ]]; then
    return 0
  fi

  if [[ -z "${AGENIC_PONY_LAUNCH_DEBUG_LOG:-}" ]]; then
    export AGENIC_PONY_LAUNCH_DEBUG_LOG="$(pony_launch_debug_path)"
  fi

  mkdir -p "$(dirname "$AGENIC_PONY_LAUNCH_DEBUG_LOG")"
  : >"$AGENIC_PONY_LAUNCH_DEBUG_LOG"
  export AGENIC_PONY_LAUNCH_DEBUG_INITIALIZED=1
}

pony_launch_debug() {
  pony_launch_debug_enabled || return 0
  pony_launch_debug_init

  local message="${1:-}"
  printf '%s [%s] %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "${0##*/}" \
    "$message" >>"$AGENIC_PONY_LAUNCH_DEBUG_LOG"
}
