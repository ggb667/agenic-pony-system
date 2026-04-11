#!/usr/bin/env bash
set -euo pipefail

personality="${1:?missing personality}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
launch_project_root="$(cd "$script_dir/../.." && pwd)"

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

export AGENIC_LAUNCH_PERSONALITY="$personality"
export AGENIC_PROJECT_ROOT="$launch_project_root"
export PONY_FUNC="$pony_func"

exec zsh -ic '
  cd "$AGENIC_PROJECT_ROOT"
  [[ -f ~/.zshrc ]] && source ~/.zshrc || true
  [[ -f ./pony/scripts/pony.zsh.support.zsh ]] && source ./pony/scripts/pony.zsh.support.zsh || true
  if [[ -n "${PONY_FUNC:-}" ]] && whence -w "$PONY_FUNC" >/dev/null 2>&1; then
    "$PONY_FUNC"
  else
    export PERSONALITY="$AGENIC_LAUNCH_PERSONALITY"
    if whence -w p10k >/dev/null 2>&1; then
      p10k reload || true
    fi
  fi
  exec ./pony/scripts/start-session.sh "$AGENIC_LAUNCH_PERSONALITY" "$AGENIC_PROJECT_ROOT"
'
