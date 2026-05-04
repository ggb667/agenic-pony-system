#!/usr/bin/env bash
set -euo pipefail

project_root="${1:?missing project root}"
fifo_path="${2:?missing fifo path}"
pid_file="${3:?missing pid file}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/pony-audio.sh"

mkdir -p "$(dirname "$fifo_path")"
rm -f "$fifo_path"
mkfifo "$fifo_path"
printf '%s\n' "$$" >"$pid_file"

cleanup() {
  rm -f "$fifo_path" "$pid_file"
}
trap cleanup EXIT

while true; do
  if IFS=$'\t' read -r tool_name prefix wav_path clip_name temp_stem <"$fifo_path"; then
    [[ -n "$tool_name" && -n "$prefix" && -n "$wav_path" && -n "$temp_stem" ]] || continue
    if [[ ! -f "$wav_path" ]]; then
      pony_audio_debug "$tool_name" "audio host request skipped missing file: $wav_path"
      continue
    fi
    pony_audio_debug "$tool_name" "audio host handling request for $wav_path"
    pony_audio_play_direct "$tool_name" "$prefix" "$wav_path" "$clip_name" "$temp_stem"
  fi
done
