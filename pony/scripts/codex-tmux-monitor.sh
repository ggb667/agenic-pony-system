#!/usr/bin/env bash
set -euo pipefail

pane_id="${1:?missing tmux pane id}"
prompt_glyph="${2:?missing prompt glyph}"
tmux_socket_path="${3:-}"
idle_sentinel="${4:-awaiting new instructions. Ω}"
partial_idle_sentinel="${5:-Ω}"
session_name="${6:-}"

consecutive_idle_polls=0
tmux_cmd=(tmux)
if [[ -n "$tmux_socket_path" ]]; then
  tmux_cmd+=( -S "$tmux_socket_path" )
fi

capture_last_nonempty_line() {
  "${tmux_cmd[@]}" capture-pane -p -t "$pane_id" -S -20 2>/dev/null \
    | tr -d '\r' \
    | awk 'NF { line=$0 } END { print line }'
}

capture_recent_pane() {
  "${tmux_cmd[@]}" capture-pane -p -t "$pane_id" -S -60 2>/dev/null | tr -d '\r'
}

trim_trailing_space() {
  sed 's/[[:space:]]*$//'
}

pane_looks_idle() {
  local recent_lines="$1"

  [[ "$recent_lines" == *"$prompt_glyph"* ]] || return 1
  [[ "$recent_lines" == *"gpt-"*"·"* ]] || return 1
  [[ "$recent_lines" != *"Working ("* ]] || return 1
  if [[ "$recent_lines" == *"$idle_sentinel"* ]] || [[ "$recent_lines" =~ (waiting\ for|awaiting)\ new\ (tasks|work|instructions|directions)\.\ Ω$ ]] || [[ "$recent_lines" == *$'\n'"$partial_idle_sentinel"$'\n'* ]] || [[ "$recent_lines" == "$partial_idle_sentinel" ]]; then
    return 0
  fi
  return 1
}

while "${tmux_cmd[@]}" display-message -p -t "$pane_id" '#{pane_id}' >/dev/null 2>&1; do
  pane_command="$("${tmux_cmd[@]}" display-message -p -t "$pane_id" '#{pane_current_command}' 2>/dev/null || true)"
  pane_text="$(capture_recent_pane)"
  recent_lines="$(printf '%s\n' "$pane_text" | awk 'NF { lines[++count]=$0 } END { start=(count>12 ? count-11 : 1); for (i=start; i<=count; ++i) print lines[i] }' | trim_trailing_space)"

  if [[ "$pane_command" == codex* ]] && pane_looks_idle "$recent_lines"; then
    consecutive_idle_polls=$((consecutive_idle_polls + 1))
  else
    consecutive_idle_polls=0
  fi

  if (( consecutive_idle_polls >= 2 )); then
    "${tmux_cmd[@]}" send-keys -t "$pane_id" C-z >/dev/null 2>&1 || true
    if [[ -n "$session_name" ]]; then
      sleep 0.1
      "${tmux_cmd[@]}" detach-client -s "$session_name" >/dev/null 2>&1 || true
    fi
    exit 0
  fi

  sleep 0.4
done
