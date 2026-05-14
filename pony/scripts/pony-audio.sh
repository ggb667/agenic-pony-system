#!/usr/bin/env bash

pony_audio_windows_ready=unknown
pony_audio_local_ready=unknown

pony_audio_trace_log_path() {
  if [[ -n "${AGENIC_PONY_AUDIO_TRACE_LOG:-}" ]]; then
    printf '%s\n' "$AGENIC_PONY_AUDIO_TRACE_LOG"
    return 0
  fi

  if [[ -n "${AGENIC_PONY_AUDIO_HOST_PID_FILE:-}" ]]; then
    printf '%s/audio.trace.log\n' "$(dirname "$AGENIC_PONY_AUDIO_HOST_PID_FILE")"
    return 0
  fi

  if [[ -n "${AGENIC_PONY_AUDIO_HOST_FIFO:-}" ]]; then
    printf '%s/audio.trace.log\n' "$(dirname "$AGENIC_PONY_AUDIO_HOST_FIFO")"
    return 0
  fi

  if [[ -n "${AGENIC_PROJECT_PONY_RUNTIME_DIR:-}" ]]; then
    printf '%s/audio.trace.log\n' "$AGENIC_PROJECT_PONY_RUNTIME_DIR"
    return 0
  fi

  return 1
}

pony_audio_trace() {
  local event="${1:?missing event}"
  shift || true
  local log_path=""

  log_path="$(pony_audio_trace_log_path 2>/dev/null || true)"
  [[ -n "$log_path" ]] || return 0
  mkdir -p "$(dirname "$log_path")" 2>/dev/null || return 0
  printf '%s [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$event" "$*" >>"$log_path" 2>/dev/null || true
}

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

  pony_audio_debug "${PONY_AUDIO_TOOL_NAME:-pony-audio}" "windows audio command available"
  pony_audio_windows_ready=yes
  return 0
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

  if [[ -n "${PULSE_SERVER:-}" ]]; then
    pony_audio_debug "$tool_name" "PulseAudio environment detected: $PULSE_SERVER"
    if command -v ffplay >/dev/null 2>&1; then
      pony_audio_debug "$tool_name" "trying ffplay via SDL pulse driver"
      pony_audio_run_with_timeout 5s env SDL_AUDIODRIVER=pulse ffplay -nodisp -autoexit -loglevel error "$wav_path" >/dev/null 2>&1 && return 0
    fi
  fi

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
  local win_tmp_dir base win_copy win_path direct_win_path ps enc

  PONY_AUDIO_TOOL_NAME="$tool_name"
  pony_audio_can_use_windows_audio || return 1
  if command -v wslpath >/dev/null 2>&1; then
    direct_win_path="$(wslpath -w "$wav_path" 2>/dev/null || true)"
    if [ -n "$direct_win_path" ]; then
      pony_audio_debug "$tool_name" "trying Windows SoundPlayer via direct WSL path $direct_win_path"
      ps=$(cat <<EOF2
\$path = '$direct_win_path'
try {
  \$player = New-Object System.Media.SoundPlayer \$path
  \$player.Load()
  \$player.PlaySync()
  Write-Output 'soundplayer_direct_ok'
  exit 0
} catch {
  exit 1
}
EOF2
)
      enc=$(printf '%s' "$ps" | iconv -f UTF-8 -t UTF-16LE | base64 -w0)
      pony_audio_run_with_timeout 12s powershell.exe -NoProfile -EncodedCommand "$enc" >/dev/null 2>&1 && return 0
    fi
  fi

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

  pony_audio_trace "play-direct.begin" "tool=$tool_name clip=${clip_name:-none} wav=$wav_path"
  pony_audio_play_wmplayer "$tool_name" "$prefix" "$wav_path" "$temp_stem" || \
    pony_audio_play_local "$tool_name" "$wav_path" || \
    pony_audio_play_fallback_beep "$tool_name" "$clip_name"
}

pony_audio_clear_stale_host_state() {
  local fifo_path="${AGENIC_PONY_AUDIO_HOST_FIFO:-}"
  local pid_file="${AGENIC_PONY_AUDIO_HOST_PID_FILE:-}"

  [[ -n "$pid_file" ]] && rm -f "$pid_file" >/dev/null 2>&1 || true
  [[ -n "$fifo_path" ]] && [[ ! -p "$fifo_path" ]] && rm -f "$fifo_path" >/dev/null 2>&1 || true
}

pony_audio_host_pid_matches() {
  local host_pid="${1:?missing host pid}"
  local args=""

  kill -0 "$host_pid" 2>/dev/null || return 1
  args="$(ps -p "$host_pid" -o args= 2>/dev/null || true)"
  [[ "$args" == *"pony-audio-host.sh"* ]]
}

pony_audio_start_host_if_possible() {
  local project_root="${AGENIC_PROJECT_ROOT:-}"
  local fifo_path="${AGENIC_PONY_AUDIO_HOST_FIFO:-}"
  local pid_file="${AGENIC_PONY_AUDIO_HOST_PID_FILE:-}"
  local runtime_dir host_script log_path host_pid

  if [[ -z "$project_root" ]]; then
    if [[ -n "$fifo_path" ]]; then
      project_root="$(cd "$(dirname "$fifo_path")/.." && pwd 2>/dev/null || true)"
    elif [[ -n "$pid_file" ]]; then
      project_root="$(cd "$(dirname "$pid_file")/.." && pwd 2>/dev/null || true)"
    fi
  fi

  [[ -n "$project_root" ]] || return 1
  runtime_dir="$project_root/pony/runtime"
  fifo_path="${fifo_path:-$runtime_dir/audio.host.fifo}"
  pid_file="${pid_file:-$runtime_dir/audio.host.pid}"
  log_path="$runtime_dir/audio.host.log"
  host_script="$project_root/pony/scripts/pony-audio-host.sh"

  [[ -x "$host_script" ]] || return 1
  export AGENIC_PROJECT_ROOT="$project_root"
  export AGENIC_PONY_AUDIO_HOST_FIFO="$fifo_path"
  export AGENIC_PONY_AUDIO_HOST_PID_FILE="$pid_file"

  if [[ -f "$pid_file" ]]; then
    read -r host_pid <"$pid_file" || host_pid=""
    if [[ -n "$host_pid" ]] && pony_audio_host_pid_matches "$host_pid"; then
      pony_audio_trace "host.start.skip" "project=$project_root pid=$host_pid already_running=yes"
      return 0
    fi
  fi

  mkdir -p "$runtime_dir"
  rm -f "$pid_file" "$fifo_path"
  pony_audio_trace "host.start.begin" "project=$project_root script=$host_script"
  nohup "$host_script" "$project_root" "$fifo_path" "$pid_file" </dev/null >>"$log_path" 2>&1 &
  sleep 0.1
  if [[ -f "$pid_file" ]]; then
    read -r host_pid <"$pid_file" || host_pid=""
    if [[ -n "$host_pid" ]] && pony_audio_host_pid_matches "$host_pid"; then
      pony_audio_trace "host.start.ok" "project=$project_root pid=$host_pid"
      return 0
    fi
  fi

  pony_audio_trace "host.start.fail" "project=$project_root"
  return 1
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

  pony_audio_trace "host.request.begin" "tool=$tool_name clip=${clip_name:-none} fifo=${fifo_path:-missing} pid_file=${pid_file:-missing}"

  if [[ -z "$fifo_path" || ! -p "$fifo_path" || -z "$pid_file" || ! -f "$pid_file" ]]; then
    pony_audio_trace "host.request.missing" "tool=$tool_name fifo_present=$([[ -n "$fifo_path" && -p "$fifo_path" ]] && printf yes || printf no) pid_present=$([[ -n "$pid_file" && -f "$pid_file" ]] && printf yes || printf no)"
    pony_audio_start_host_if_possible || true
  fi

  [[ -n "$fifo_path" && -p "$fifo_path" ]] || return 1
  [[ -n "$pid_file" && -f "$pid_file" ]] || return 1
  read -r host_pid <"$pid_file" || host_pid=""
  [[ -n "$host_pid" ]] || {
    pony_audio_trace "host.request.empty-pid" "tool=$tool_name"
    pony_audio_clear_stale_host_state
    return 1
  }
  if ! pony_audio_host_pid_matches "$host_pid"; then
    pony_audio_trace "host.request.stale-pid" "tool=$tool_name pid=$host_pid"
    pony_audio_clear_stale_host_state
    pony_audio_start_host_if_possible || true
    [[ -n "$pid_file" && -f "$pid_file" ]] || return 1
    read -r host_pid <"$pid_file" || host_pid=""
    [[ -n "$host_pid" ]] || return 1
    pony_audio_host_pid_matches "$host_pid" || return 1
  fi

  pony_audio_debug "$tool_name" "requesting audio host playback via $fifo_path"
  pony_audio_run_with_timeout 1s bash -c '
    fifo_path="$1"
    shift
    printf "%s\t%s\t%s\t%s\t%s\n" "$@" >"$fifo_path"
  ' bash "$fifo_path" "$tool_name" "$prefix" "$wav_path" "$clip_name" "$temp_stem" >/dev/null 2>&1
  local write_status=$?
  pony_audio_trace "host.request.end" "tool=$tool_name pid=$host_pid status=$write_status"
  return $write_status
}
