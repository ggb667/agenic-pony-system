#!/usr/bin/env bash
set -euo pipefail

project_root="${1:?missing project root}"
fifo_path="${2:?missing fifo path}"
pid_file="${3:?missing pid file}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/pony-audio.sh"
export AGENIC_PROJECT_ROOT="$project_root"
export AGENIC_PONY_AUDIO_HOST_FIFO="$fifo_path"
export AGENIC_PONY_AUDIO_HOST_PID_FILE="$pid_file"

mkdir -p "$(dirname "$fifo_path")"
rm -f "$fifo_path"
mkfifo "$fifo_path"
printf '%s\n' "$$" >"$pid_file"
pony_audio_trace "host.loop.start" "project=$project_root pid=$$ fifo=$fifo_path"
exec 3<>"$fifo_path"

cleanup() {
  pony_audio_trace "host.loop.stop" "project=$project_root pid=$$"
  exec 3>&- || true
  rm -f "$fifo_path" "$pid_file"
}
trap cleanup EXIT

while true; do
  if IFS=$'\t' read -r -u 3 tool_name prefix wav_path clip_name temp_stem; then
    [[ -n "$tool_name" && -n "$prefix" && -n "$wav_path" && -n "$temp_stem" ]] || continue
    if [[ ! -f "$wav_path" ]]; then
      pony_audio_trace "host.loop.missing-file" "tool=$tool_name wav=$wav_path"
      pony_audio_debug "$tool_name" "audio host request skipped missing file: $wav_path"
      continue
    fi
    pony_audio_trace "host.loop.request" "tool=$tool_name clip=${clip_name:-none} wav=$wav_path"
    pony_audio_debug "$tool_name" "audio host handling request for $wav_path"
    pony_audio_play_direct "$tool_name" "$prefix" "$wav_path" "$clip_name" "$temp_stem"
    pony_audio_trace "host.loop.complete" "tool=$tool_name clip=${clip_name:-none}"
  fi
done
