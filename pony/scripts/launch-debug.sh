#!/usr/bin/env bash
set -euo pipefail

pony_launch_debug_enabled() {
  return 0
}

pony_launch_debug_init() {
  pony_launch_debug_enabled || return 0

  if [[ "${AGENIC_PONY_LAUNCH_DEBUG_INITIALIZED:-0}" == "1" ]] && [[ -n "${AGENIC_PONY_LAUNCH_DEBUG_LOG:-}" ]]; then
    return 0
  fi

  if [[ -z "${AGENIC_PONY_LAUNCH_DEBUG_LOG:-}" ]]; then
    export AGENIC_PONY_LAUNCH_DEBUG_LOG="${TMPDIR:-/tmp}/agenic-pony-launch-current.log"
  fi

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
