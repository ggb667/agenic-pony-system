#!/usr/bin/env bash
set -euo pipefail

pony_launch_debug_enabled() {
  [[ "${AGENIC_PONY_LAUNCH_DEBUG:-0}" == "1" ]]
}

pony_launch_debug_init() {
  pony_launch_debug_enabled || return 0

  if [[ -z "${AGENIC_PONY_LAUNCH_DEBUG_LOG:-}" ]]; then
    local stamp
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    export AGENIC_PONY_LAUNCH_DEBUG_LOG="${TMPDIR:-/tmp}/agenic-pony-launch-${USER:-user}-${stamp}-$$.log"
  fi

  if [[ ! -e "$AGENIC_PONY_LAUNCH_DEBUG_LOG" ]]; then
    : >"$AGENIC_PONY_LAUNCH_DEBUG_LOG"
  fi
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
