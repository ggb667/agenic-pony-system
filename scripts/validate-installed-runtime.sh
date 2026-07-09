#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
agenic_root="$(cd "$script_dir/.." && pwd)"
source "$agenic_root/pony/scripts/pony-paths.sh"

target_root="${1:-$PWD}"
resolved_target_root="$(detect_project_root "$target_root")"

runtime_dir="$resolved_target_root/pony/runtime"
state_file="$runtime_dir/install-project.state"
metadata_file="$runtime_dir/install-project.metadata"
fingerprint_file="$runtime_dir/source-runtime.fingerprint"
runtime_state_file="$runtime_dir/runtime.state"
installed_prompt="$resolved_target_root/pony/launch.prompts/twi.txt"
installed_shell_launcher="$resolved_target_root/pony/scripts/launch-in-pony-shell.sh"
installed_entry_launcher="$resolved_target_root/pony/scripts/enter-worker-from-prompt-file.sh"
installed_direct_launcher="$resolved_target_root/pony/scripts/enter-worker-and-codex.sh"
installed_host="$resolved_target_root/pony/scripts/pony-session-host.py"
installed_wrapper="$resolved_target_root/pony/bin/codex-pony"
installed_pony_tell="$resolved_target_root/pony/bin/pony-tell"
legacy_pony_mail="$resolved_target_root/pony/bin/pony-mail"
source_codex_pony="$agenic_root/pony/bin/codex-pony"
source_pony_tell="$agenic_root/pony/bin/pony-tell"
source_start_session="$agenic_root/pony/scripts/start-session.sh"

failures=()

record_failure() {
  failures+=("$1")
}

require_file() {
  local path="${1:?missing path}"
  local label="${2:?missing label}"
  if [[ ! -f "$path" ]]; then
    record_failure "$label missing: $path"
    return 1
  fi
}

expect_contains() {
  local path="${1:?missing path}"
  local needle="${2:?missing needle}"
  local label="${3:?missing label}"
  if ! grep -Fq -- "$needle" "$path"; then
    record_failure "$label missing expected text: $needle"
  fi
}

expect_absent() {
  local path="${1:?missing path}"
  local needle="${2:?missing needle}"
  local label="${3:?missing label}"
  if grep -Fq -- "$needle" "$path"; then
    record_failure "$label still contains stale text: $needle"
  fi
}

require_file "$state_file" "install state"
require_file "$metadata_file" "install metadata"
require_file "$fingerprint_file" "installed fingerprint"
require_file "$runtime_state_file" "runtime state"
require_file "$installed_prompt" "installed Twilight prompt"
require_file "$installed_shell_launcher" "installed shell launcher"
require_file "$installed_entry_launcher" "installed worker entry launcher"
require_file "$installed_direct_launcher" "installed direct worker launcher"
require_file "$installed_host" "installed pony session host"
require_file "$installed_wrapper" "installed codex-pony wrapper"
require_file "$installed_pony_tell" "installed pony-tell"
require_file "$source_codex_pony" "source codex-pony"
require_file "$source_pony_tell" "source pony-tell"
require_file "$source_start_session" "source start-session"

if [[ ! -x "$installed_pony_tell" ]]; then
  record_failure "installed pony-tell is not executable: $installed_pony_tell"
fi

if [[ ! -x "$source_pony_tell" ]]; then
  record_failure "source pony-tell is not executable: $source_pony_tell"
fi

if [[ -e "$legacy_pony_mail" ]]; then
  record_failure "legacy pony-mail should not exist: $legacy_pony_mail"
fi

install_state=""
if [[ -f "$state_file" ]]; then
  read -r install_state <"$state_file" || install_state=""
  if [[ "$install_state" != "complete" ]]; then
    record_failure "install state is not complete: ${install_state:-missing}"
  fi
fi

runtime_state=""
if [[ -f "$runtime_state_file" ]]; then
  read -r runtime_state <"$runtime_state_file" || runtime_state=""
  if [[ "$runtime_state" != "ready" ]]; then
    record_failure "runtime state is not ready: ${runtime_state:-missing}"
  fi
fi

installed_fingerprint=""
if [[ -f "$fingerprint_file" ]]; then
  read -r installed_fingerprint <"$fingerprint_file" || installed_fingerprint=""
fi
source_fingerprint="$("$agenic_root/pony/scripts/runtime-fingerprint.sh")"
if [[ "$installed_fingerprint" != "$source_fingerprint" ]]; then
  record_failure "installed runtime fingerprint is stale: installed=${installed_fingerprint:-missing} source=$source_fingerprint"
fi

if [[ -f "$metadata_file" ]]; then
  expect_contains "$metadata_file" "project_root: $resolved_target_root" "install metadata"
fi

if [[ -f "$installed_prompt" ]]; then
  expect_contains "$installed_prompt" "simple \`/tell\` ping, greeting, acknowledgement, or short live coordination note" "installed Twilight prompt"
  expect_contains "$installed_prompt" "still applies when Twilight is otherwise WAITING, unassigned" "installed Twilight prompt"
  expect_contains "$installed_prompt" "source.runtime.summary.md" "installed Twilight prompt"
  expect_absent "$installed_prompt" "8. \`README.md\`" "installed Twilight prompt"
  expect_absent "$installed_prompt" "9. \`docs/runtime-loop.md\`" "installed Twilight prompt"
  expect_absent "$installed_prompt" "10. \`docs/project-installation.md\`" "installed Twilight prompt"
fi

if [[ -f "$installed_shell_launcher" ]]; then
  expect_contains "$installed_shell_launcher" 'FLUTTERSHY) pony_func="fluttershy"' "installed shell launcher"
  expect_contains "$installed_shell_launcher" 'RAINBOW_DASH) pony_func="rainbow"' "installed shell launcher"
  expect_contains "$installed_shell_launcher" 'FLUTTERSHY) pony_label="Fluttershy"' "installed shell launcher"
  expect_contains "$installed_shell_launcher" 'RAINBOW_DASH) pony_label="Rainbow Dash"' "installed shell launcher"
fi

if [[ -f "$installed_entry_launcher" ]]; then
  expect_contains "$installed_entry_launcher" 'direct_launcher="$(pony_script_path enter-worker-and-codex.sh)"' "installed worker entry launcher"
  expect_contains "$installed_entry_launcher" 'if [[ "$personality" != "PRINCESS_CELESTIA_SOL_INVICTUS" ]]; then' "installed worker entry launcher"
  expect_contains "$installed_entry_launcher" 'host_script="$(pony_script_path pony-session-host.py)"' "installed worker entry launcher"
  expect_contains "$installed_entry_launcher" '--session-name "$session_name"' "installed worker entry launcher"
  expect_contains "$installed_entry_launcher" '--socket-path "$socket_path"' "installed worker entry launcher"
fi

if [[ -f "$installed_direct_launcher" ]]; then
  expect_contains "$installed_direct_launcher" 'clean_stale_tmux_state_for_direct_launch()' "installed direct worker launcher"
  expect_contains "$installed_direct_launcher" 'tmux -S "$socket_path" kill-server' "installed direct worker launcher"
  expect_contains "$installed_direct_launcher" 'clean_stale_tmux_state_for_direct_launch "$PERSONALITY"' "installed direct worker launcher"
fi

if [[ -f "$installed_host" ]]; then
  expect_contains "$installed_host" 'if result == "READY_KEEP_LIVE":' "installed pony session host"
  expect_contains "$installed_host" 'model_instructions_file=' "installed pony session host"
  expect_contains "$installed_host" 'Startup behavior: greet the developer in character with a concise startup self-brief.' "installed pony session host"
  expect_contains "$installed_host" 'capture=True, check=False' "installed pony session host"
fi

if [[ -f "$installed_wrapper" ]]; then
  expect_contains "$installed_wrapper" 'resolve-system-root.sh' "installed codex-pony wrapper"
fi

expect_contains "$source_codex_pony" 'tui.terminal_title=[]' "source codex-pony"
expect_contains "$source_start_session" 'inside this project, use $AGENIC_PROJECT_PONY_BIN_DIR/pony-tell <pony|all> <message>.' "source start-session"
expect_contains "$source_start_session" 'only contact her when the user explicitly assigns source-repo governance work.' "source start-session"

if (( ${#failures[@]} > 0 )); then
  printf '%s\n' "Installed runtime validation FAILED for $resolved_target_root"
  for failure in "${failures[@]}"; do
    printf '%s\n' "- $failure"
  done
  exit 1
fi

printf '%s\n' "Installed runtime validation passed for $resolved_target_root"
printf '%s\n' "- install state: complete"
printf '%s\n' "- runtime state token is ready"
printf '%s\n' "- runtime fingerprint matches source: $source_fingerprint"
printf '%s\n' "- source and installed pony-tell are executable and legacy pony-mail is absent"
printf '%s\n' "- Twilight prompt contains live ping reply guidance and compact source summary reference"
printf '%s\n' "- launcher surfaces retain the expected title, pony-name mappings, hidden model instructions, stale tmux cleanup for direct-launch ponies, direct worker and Twilight Codex surface, and parked-host Celestia path"
