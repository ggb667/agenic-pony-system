#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/pony-paths.sh"

usage() {
  printf '%s\n' "Usage: $(basename "$0") [--direct] PERSONALITY" >&2
}

while (($#)); do
  case "$1" in
    --direct)
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      printf '%s\n' "Unknown option: $1" >&2
      usage
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

[[ $# -ge 1 ]] || {
  usage
  exit 2
}

raw_personality="${1:?missing personality}"
personality="$(canonical_personality "$raw_personality" 2>/dev/null || printf '%s' "$raw_personality")"
project_root="$(cd "$script_dir/../.." && pwd)"

"$script_dir/prepare-team-launch.sh" "$project_root"
exec "$script_dir/launch-in-pony-shell.sh" "$personality"
