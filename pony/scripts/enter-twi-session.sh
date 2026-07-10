#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/launch-debug.sh"
source "$script_dir/pony-paths.sh"
load_project_paths "$(cd "$script_dir/../.." && pwd)"
pony_launch_debug_init

watch_script="$(pony_script_path watch-twi.sh)"
pony_ensure_layout_dirs
log_file="$AGENIC_PROJECT_PONY_AGENTS_DIR/twi.watch.log"
registry_file="$(pony_assignment_registry_path)"
override_promptfile="${1:-}"
pony_launch_debug "enter-twi-session entry: project_root=$AGENIC_PROJECT_ROOT watch_script=$watch_script override_promptfile=${override_promptfile:-none}"

mkdir -p "$AGENIC_PROJECT_PONY_AGENTS_DIR"
pkill -f "$watch_script" >/dev/null 2>&1 || true
nohup "$watch_script" >"$log_file" 2>&1 &
disown || true
pony_launch_debug "enter-twi-session watch started: log_file=$log_file"

assignment_row="$(
  python3 - "$registry_file" <<'PY'
import csv
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
if not registry_path.exists():
    raise SystemExit(0)
rows = list(csv.DictReader(registry_path.open(), delimiter='\t'))
for row in rows:
    if row['personality'] == 'TWILIGHT_SPARKLE':
        print("\t".join([row['workfile'], row['worktree'], row['promptfile']]))
        raise SystemExit(0)
PY
)"

twi_workfile="$AGENIC_PROJECT_PONY_WORK_DIR/$(workfile_name_for_slug twi)"
twi_rootdir="$AGENIC_PROJECT_ROOT"
twi_promptfile="$(pony_launch_prompt_path twi.txt)"
if [[ -n "$assignment_row" ]]; then
  IFS=$'\t' read -r twi_workfile twi_rootdir twi_promptfile <<<"$assignment_row"
fi
if [[ -n "$override_promptfile" ]]; then
  twi_promptfile="$override_promptfile"
fi

pony_launch_debug "enter-twi-session resolved paths: workfile=$twi_workfile rootdir=$twi_rootdir promptfile=$twi_promptfile assignment_override=$( [[ -n "$assignment_row" ]] && printf yes || printf no )"

entry_launcher="$(pony_script_path enter-worker-and-codex.sh)"
pony_launch_debug "enter-twi-session exec direct Twilight handoff: launcher=$entry_launcher workfile=$twi_workfile rootdir=$twi_rootdir promptfile=$twi_promptfile"
exec "$entry_launcher"   TWILIGHT_SPARKLE   "$twi_workfile"   "$twi_rootdir"   "$twi_promptfile"
