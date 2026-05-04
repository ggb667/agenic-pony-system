#!/usr/bin/env bash

pony_audio_windows_ready=unknown
pony_audio_local_ready=unknown

pony_audio_debug() {
  local tool_name="${1:?missing tool name}"
  shift
  if [ "${PONYDEBUG:-0}" = "1" ]; then
    printf '%s: %s\n' "$tool_name" "$*" >&2
  fi
}

pony_audio_run_with_timeout() {
  local duration="${1:-5s}"
  shift || true
  if command -v timeout >/dev/null 2>&1; then
    timeout "$duration" "$@"
  else
    "$@"
  fi
}

pony_audio_can_use_windows_audio() {
  if [ "$pony_audio_windows_ready" = "yes" ]; then
    pony_audio_debug "${PONY_AUDIO_TOOL_NAME:-pony-audio}" "windows audio probe cached yes"
    return 0
  fi
  if [ "$pony_audio_windows_ready" = "no" ]; then
    pony_audio_debug "${PONY_AUDIO_TOOL_NAME:-pony-audio}" "windows audio probe cached no"
    return 1
  fi

  command -v powershell.exe >/dev/null 2>&1 || {
    pony_audio_debug "${PONY_AUDIO_TOOL_NAME:-pony-audio}" "windows audio unavailable: powershell.exe not found"
    pony_audio_windows_ready=no
    return 1
  }

  if powershell.exe -NoProfile -Command "exit 0" >/dev/null 2>&1; then
    pony_audio_debug "${PONY_AUDIO_TOOL_NAME:-pony-audio}" "windows audio probe succeeded"
    pony_audio_windows_ready=yes
    return 0
  fi

  pony_audio_debug "${PONY_AUDIO_TOOL_NAME:-pony-audio}" "windows audio probe failed"
  pony_audio_windows_ready=no
  return 1
}

pony_audio_can_use_local_audio() {
  if [ "$pony_audio_local_ready" = "yes" ]; then
    pony_audio_debug "${PONY_AUDIO_TOOL_NAME:-pony-audio}" "local audio probe cached yes"
    return 0
  fi
  if [ "$pony_audio_local_ready" = "no" ]; then
    pony_audio_debug "${PONY_AUDIO_TOOL_NAME:-pony-audio}" "local audio probe cached no"
    return 1
  fi

  command -v ffplay >/dev/null 2>&1 || {
    pony_audio_debug "${PONY_AUDIO_TOOL_NAME:-pony-audio}" "local audio unavailable: ffplay not found"
    pony_audio_local_ready=no
    return 1
  }

  if pony_audio_run_with_timeout 2s ffplay -nodisp -autoexit -loglevel error -f lavfi -t 0.1 anullsrc=r=48000:cl=mono >/dev/null 2>&1; then
    pony_audio_debug "${PONY_AUDIO_TOOL_NAME:-pony-audio}" "local audio probe succeeded"
    pony_audio_local_ready=yes
    return 0
  fi

  pony_audio_debug "${PONY_AUDIO_TOOL_NAME:-pony-audio}" "local audio probe failed"
  pony_audio_local_ready=no
  return 1
}

pony_audio_play_local() {
  local tool_name="${1:?missing tool name}"
  local wav_path="${2:?missing wav path}"

  if pony_audio_can_use_local_audio; then
    pony_audio_debug "$tool_name" "trying ffplay"
    pony_audio_run_with_timeout 5s ffplay -nodisp -autoexit -loglevel error "$wav_path" >/dev/null 2>&1 && return 0
  fi
  if command -v aplay >/dev/null 2>&1; then
    pony_audio_debug "$tool_name" "trying aplay"
    pony_audio_run_with_timeout 5s aplay -q "$wav_path" >/dev/null 2>&1 && return 0
  fi
  if command -v paplay >/dev/null 2>&1; then
    pony_audio_debug "$tool_name" "trying paplay"
    pony_audio_run_with_timeout 5s paplay "$wav_path" >/dev/null 2>&1 && return 0
  fi
  return 1
}

pony_audio_play_wmplayer() {
  local tool_name="${1:?missing tool name}"
  local prefix="${2:?missing prefix}"
  local wav_path="${3:?missing wav path}"
  local temp_stem="${4:?missing temp stem}"
  local win_tmp_dir base win_copy win_path ps enc

  PONY_AUDIO_TOOL_NAME="$tool_name"
  pony_audio_can_use_windows_audio || return 1
  win_tmp_dir="/mnt/c/Users/${USER}/AppData/Local/Temp"
  [ -d "$win_tmp_dir" ] || return 1

  base="${temp_stem}-${prefix}$$-$RANDOM.wav"
  win_copy="$win_tmp_dir/$base"
  pony_audio_debug "$tool_name" "trying Windows audio via $win_copy"
  cp "$wav_path" "$win_copy" >/dev/null 2>&1 || return 1

  win_path="C:\\Users\\${USER}\\AppData\\Local\\Temp\\$base"
  ps=$(cat <<EOF2
\$path = '$win_path'
\$player = \$null
try {
  \$player = New-Object System.Media.SoundPlayer \$path
  \$player.Load()
  \$player.PlaySync()
  Remove-Item \$path -ErrorAction SilentlyContinue
  Write-Output 'soundplayer_ok'
  exit 0
} catch {
}
\$p = Start-Process -FilePath 'C:\Program Files (x86)\Windows Media Player\wmplayer.exe' -ArgumentList \$path -WindowStyle Minimized -PassThru
Start-Sleep -Seconds 4
if (-not \$p.HasExited) {
  Stop-Process -Id \$p.Id -Force
}
Remove-Item \$path -ErrorAction SilentlyContinue
Write-Output 'wmplayer_ok'
EOF2
)
  enc=$(printf '%s' "$ps" | iconv -f UTF-8 -t UTF-16LE | base64 -w0)

  pony_audio_run_with_timeout 12s powershell.exe -NoProfile -EncodedCommand "$enc" >/dev/null 2>&1 && return 0
  rm -f "$win_copy" >/dev/null 2>&1 || true
  return 1
}

pony_audio_play_fallback_beep() {
  local tool_name="${1:?missing tool name}"
  local clip_name="${2:-}"

  pony_audio_debug "$tool_name" "using double bell fallback"
  if [ -n "$clip_name" ]; then
    printf '%s: audio playback failed for %s; using bell fallback\n' "$tool_name" "$clip_name" >&2
  fi
  printf '\a'
  sleep 0.15
  printf '\a'
}

pony_audio_play_direct() {
  local tool_name="${1:?missing tool name}"
  local prefix="${2:?missing prefix}"
  local wav_path="${3:?missing wav path}"
  local clip_name="${4:-}"
  local temp_stem="${5:?missing temp stem}"

  pony_audio_play_wmplayer "$tool_name" "$prefix" "$wav_path" "$temp_stem" || \
    pony_audio_play_local "$tool_name" "$wav_path" || \
    pony_audio_play_fallback_beep "$tool_name" "$clip_name"
}

pony_audio_request_host_play() {
  local tool_name="${1:?missing tool name}"
  local prefix="${2:?missing prefix}"
  local wav_path="${3:?missing wav path}"
  local clip_name="${4:-}"
  local temp_stem="${5:?missing temp stem}"
  local fifo_path="${AGENIC_PONY_AUDIO_HOST_FIFO:-}"
  local pid_file="${AGENIC_PONY_AUDIO_HOST_PID_FILE:-}"
  local host_pid=""

  [[ -n "$fifo_path" && -p "$fifo_path" ]] || return 1
  [[ -n "$pid_file" && -f "$pid_file" ]] || return 1
  read -r host_pid <"$pid_file" || host_pid=""
  [[ -n "$host_pid" ]] || return 1
  kill -0 "$host_pid" 2>/dev/null || return 1

  pony_audio_debug "$tool_name" "requesting audio host playback via $fifo_path"
  pony_audio_run_with_timeout 1s bash -c '
    fifo_path="$1"
    shift
    printf "%s\t%s\t%s\t%s\t%s\n" "$@" >"$fifo_path"
  ' bash "$fifo_path" "$tool_name" "$prefix" "$wav_path" "$clip_name" "$temp_stem" >/dev/null 2>&1
}
