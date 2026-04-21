#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../pony/scripts/pony-paths.sh"

source_pony_root="$pony_root"
source_pony_bin_dir="$pony_bin_dir"
source_pony_scripts_dir="$pony_scripts_dir"
source_pony_launch_prompts_dir="$pony_launch_prompts_dir"

target_root="${1:-$PWD}"
load_project_paths "$target_root"

while IFS= read -r dir; do
  mkdir -p "$dir"
done < <(project_pony_dirs)

write_file_if_missing() {
  local path="${1:?missing path}"
  local content="${2-}"
  if [[ ! -e "$path" ]]; then
    printf '%s' "$content" >"$path"
  fi
}

copy_file_if_missing() {
  local source_path="${1:?missing source path}"
  local target_path="${2:?missing target path}"
  if [[ ! -e "$target_path" ]]; then
    cp "$source_path" "$target_path"
  fi
}

write_managed_executable() {
  local path="${1:?missing path}"
  local content="${2-}"
  printf '%s' "$content" >"$path"
  chmod +x "$path"
}

write_managed_file() {
  local path="${1:?missing path}"
  local content="${2-}"
  printf '%s' "$content" >"$path"
}

ensure_git_exclude_rule() {
  local pattern="${1:?missing pattern}"
  git -C "$AGENIC_PROJECT_ROOT" rev-parse --show-toplevel >/dev/null 2>&1 || return 0

  local exclude_path
  exclude_path="$(git -C "$AGENIC_PROJECT_ROOT" rev-parse --git-path info/exclude)"
  if [[ "$exclude_path" != /* ]]; then
    exclude_path="$AGENIC_PROJECT_ROOT/$exclude_path"
  fi
  mkdir -p "$(dirname "$exclude_path")"
  local begin_marker="# BEGIN AGENIC PONY MANAGED RULES"
  local end_marker="# END AGENIC PONY MANAGED RULES"
  local existing=""
  if [[ -f "$exclude_path" ]]; then
    existing="$(cat "$exclude_path")"
  fi

  python3 - "$exclude_path" "$begin_marker" "$end_marker" "$pattern" "$existing" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
begin = sys.argv[2]
end = sys.argv[3]
pattern = sys.argv[4]
existing = sys.argv[5]

lines = existing.splitlines()
result = []
inside = False

for line in lines:
    if line == begin:
        inside = True
        continue
    if line == end:
        inside = False
        continue
    if not inside:
        result.append(line)

while result and result[-1] == "":
    result.pop()

if result:
    result.append("")
result.extend([begin, pattern, end, ""])
path.write_text("\n".join(result), encoding="utf-8")
PY
}

write_workfile_if_missing() {
  local slug="${1:?missing worker slug}"
  local title
  title="$(worker_label_for_slug "$slug")"
  local workfile="$AGENIC_PROJECT_PONY_WORK_DIR/$(workfile_name_for_slug "$slug")"
  write_file_if_missing "$workfile" "$(cat <<EOF
# ${title} Workfile

Project: $AGENIC_PROJECT_NAME
Branch: $AGENIC_PROJECT_BRANCH

Status: blank
Scope: unassigned
Notes:
- no assigned work yet
EOF
)"
}

project_supports_worker_worktrees() {
  if is_agenic_source_project; then
    return 1
  fi
  git -C "$AGENIC_PROJECT_ROOT" rev-parse --show-toplevel >/dev/null 2>&1 || return 1
  [[ "$AGENIC_PROJECT_BRANCH" != "no-git-branch" ]]
}

ensure_worker_worktree() {
  local slug="${1:?missing worker slug}"
  local worktree_dir
  local branch_name

  worktree_dir="$(worker_worktree_for_slug "$slug")"
  branch_name="$(worker_branch_for_slug "$slug")"

  [[ "$worktree_dir" != "$AGENIC_PROJECT_ROOT" ]] || return 0
  project_supports_worker_worktrees || return 0

  if git -C "$worktree_dir" rev-parse --show-toplevel >/dev/null 2>&1; then
    return 0
  fi

  mkdir -p "$(dirname "$worktree_dir")"
  if git -C "$AGENIC_PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$branch_name"; then
    git -C "$AGENIC_PROJECT_ROOT" worktree add "$worktree_dir" "$branch_name" >/dev/null
  else
    git -C "$AGENIC_PROJECT_ROOT" worktree add -b "$branch_name" "$worktree_dir" HEAD >/dev/null
  fi
}

sync_worker_worktree_runtime() {
  local slug="${1:?missing worker slug}"
  local worktree_dir
  local worktree_pony_dir
  local worktree_pony_bin_dir
  local worktree_pony_scripts_dir

  worktree_dir="$(worker_worktree_for_slug "$slug")"
  [[ "$worktree_dir" != "$AGENIC_PROJECT_ROOT" ]] || return 0
  project_supports_worker_worktrees || return 0
  [[ -d "$worktree_dir" ]] || return 0

  worktree_pony_dir="$worktree_dir/pony"
  worktree_pony_bin_dir="$worktree_pony_dir/bin"
  worktree_pony_scripts_dir="$worktree_pony_dir/scripts"
  mkdir -p "$worktree_pony_bin_dir" "$worktree_pony_scripts_dir"

  write_managed_file "$worktree_pony_dir/README.md" "$(cat <<EOF
# pony

Worker-worktree pony wrappers for $AGENIC_PROJECT_NAME.

These wrappers delegate to the owning project runtime at:
$AGENIC_PROJECT_ROOT/pony
EOF
)"

  write_managed_file "$worktree_pony_dir/pony.system.config.yaml" "$(cat <<EOF
project_name: $AGENIC_PROJECT_NAME
project_root: $AGENIC_PROJECT_ROOT
branch: $AGENIC_PROJECT_BRANCH
launcher_prefix: $AGENIC_PROJECT_NAME Pony
agenic_system_root: $agenic_root
agenic_system_repo: $(git -C "$agenic_root" remote get-url origin 2>/dev/null || printf '%s' "https://github.com/ggb667/agenic-pony-system.git")
agenic_system_ref: main
EOF
)"

  write_managed_executable "$worktree_pony_scripts_dir/resolve-system-root.sh" "$(cat "$source_pony_scripts_dir/resolve-system-root.sh")"

  write_managed_executable "$worktree_pony_scripts_dir/start-session.sh" "$(cat <<EOF
#!/usr/bin/env bash
set -euo pipefail
project_root="$AGENIC_PROJECT_ROOT"
resolver="\$project_root/pony/scripts/resolve-system-root.sh"
unset AGENIC_PONY_SOURCE_ROOT
source_root="\$("\$resolver" "\$project_root")"
export AGENIC_PONY_SOURCE_ROOT="\$source_root"
exec "\$source_root/pony/scripts/start-session.sh" "\${1:?missing personality}" "\$project_root"
EOF
)"

  write_managed_executable "$worktree_pony_scripts_dir/launch-in-pony-shell.sh" "$(cat <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$AGENIC_PROJECT_ROOT/pony/scripts/launch-in-pony-shell.sh" "\${1:?missing personality}"
EOF
)"

  write_managed_file "$worktree_pony_scripts_dir/pony.zsh.support.zsh" "$(cat <<EOF
export AGENIC_PROJECT_ROOT="$AGENIC_PROJECT_ROOT"
source "$AGENIC_PROJECT_ROOT/pony/scripts/pony.zsh.support.zsh"
EOF
)"

  write_managed_executable "$worktree_pony_bin_dir/codex-pony" "$(cat <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$AGENIC_PROJECT_ROOT/pony/bin/codex-pony" "\$@"
EOF
)"
}

write_project_config_if_missing() {
  local source_repo
  source_repo="$(git -C "$agenic_root" remote get-url origin 2>/dev/null || true)"
  [[ -n "$source_repo" ]] || source_repo="https://github.com/ggb667/agenic-pony-system.git"
  write_file_if_missing "$AGENIC_PROJECT_PONY_CONFIG_PATH" "$(cat <<EOF
project_name: $AGENIC_PROJECT_NAME
project_root: $AGENIC_PROJECT_ROOT
branch: $AGENIC_PROJECT_BRANCH
launcher_prefix: $AGENIC_PROJECT_NAME Pony
agenic_system_root: $agenic_root
agenic_system_repo: $source_repo
agenic_system_ref: main
EOF
)"
  python3 - "$AGENIC_PROJECT_PONY_CONFIG_PATH" "$agenic_root" "$source_repo" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
agenic_root = sys.argv[2]
source_repo = sys.argv[3]
text = path.read_text(encoding="utf-8")
lines = text.splitlines()
result = []
seen_root = False
seen_repo = False
seen_ref = False

for line in lines:
    if line.startswith("agenic_system_root:") and "agenic_system_repo:" in line:
        left, right = line.split("agenic_system_repo:", 1)
        line = left.rstrip()
        if line:
            result.append(f"agenic_system_root: {agenic_root}")
            seen_root = True
        result.append(f"agenic_system_repo: {source_repo}")
        seen_repo = True
        continue
    if line.startswith("agenic_system_root:"):
        if not seen_root:
            result.append(f"agenic_system_root: {agenic_root}")
            seen_root = True
        continue
    if line.startswith("agenic_system_repo:"):
        if not seen_repo:
            result.append(f"agenic_system_repo: {source_repo}")
            seen_repo = True
        continue
    if line.startswith("agenic_system_ref:"):
        if not seen_ref:
            result.append("agenic_system_ref: main")
            seen_ref = True
        continue
    result.append(line)

if not seen_root:
    result.append(f"agenic_system_root: {agenic_root}")
if not seen_repo:
    result.append(f"agenic_system_repo: {source_repo}")
if not seen_ref:
    result.append("agenic_system_ref: main")

path.write_text("\n".join(result) + "\n", encoding="utf-8")
PY
}

is_agenic_source_project() {
  [[ "$AGENIC_PROJECT_ROOT" == "$agenic_root" ]]
}

write_shell_launcher_if_missing() {
  local path="${1:?missing launcher path}"
  local personality="${2:?missing personality}"
  write_managed_executable "$path" "$(cat <<EOF
#!/usr/bin/env bash
set -euo pipefail
cd "$AGENIC_PROJECT_ROOT"
exec "$AGENIC_PROJECT_PONY_SCRIPTS_DIR/launch-in-pony-shell.sh" "$personality"
EOF
)"
}

remove_if_exists() {
  local path="${1:?missing path}"
  rm -f "$path"
}

write_status_if_missing() {
  local slug="${1:?missing worker slug}"
  local worker_branch
  local worker_worktree
  local branch_verified="yes"
  worker_branch="$(worker_branch_for_slug "$slug")"
  worker_worktree="$(worker_worktree_for_slug "$slug")"
  if [[ "$worker_branch" == "no-git-branch" ]]; then
    branch_verified="n/a"
  fi
  write_file_if_missing "$AGENIC_TEAM_COORDINATION_DIR/${slug}.status.md" "$(cat <<EOF
AUDIENCE: EVERYONE
BRANCH: $worker_branch
WORKTREE: $worker_worktree
BRANCH_VERIFIED: $branch_verified
STATUS: WAITING
PUSH_STATUS: clean_local_branch
FILES_PLANNED: none
FILES_TOUCHED: none
BLOCKERS: none
NEXT_STEP: waiting for a concrete task
QUESTIONS_FOR_TWI: none
DECISION_NEEDED: none
EOF
)"
}

heal_status_assignment_if_default() {
  local slug="${1:?missing worker slug}"
  local status_file="$AGENIC_TEAM_COORDINATION_DIR/${slug}.status.md"
  local worker_branch
  local worker_worktree
  local current_branch
  local current_worktree

  [[ -f "$status_file" ]] || return 0
  worker_branch="$(worker_branch_for_slug "$slug")"
  worker_worktree="$(worker_worktree_for_slug "$slug")"
  [[ "$worker_worktree" != "$AGENIC_PROJECT_ROOT" ]] || return 0

  current_branch="$(sed -n 's/^BRANCH: //p' "$status_file" | head -n 1)"
  current_worktree="$(sed -n 's/^WORKTREE: //p' "$status_file" | head -n 1)"

  if [[ "$current_branch" == "$AGENIC_PROJECT_BRANCH" ]] && [[ "$current_worktree" == "$AGENIC_PROJECT_ROOT" ]]; then
    python3 - "$status_file" "$worker_branch" "$worker_worktree" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
branch = sys.argv[2]
worktree = sys.argv[3]
lines = path.read_text(encoding="utf-8").splitlines()
result = []
for line in lines:
    if line.startswith("BRANCH: "):
        result.append(f"BRANCH: {branch}")
    elif line.startswith("WORKTREE: "):
        result.append(f"WORKTREE: {worktree}")
    elif line.startswith("BRANCH_VERIFIED: "):
        result.append("BRANCH_VERIFIED: yes")
    else:
        result.append(line)
path.write_text("\n".join(result) + "\n", encoding="utf-8")
PY
  fi
}

sync_assignment_registry() {
  local registry_path="$AGENIC_TEAM_COORDINATION_DIR/assignment.registry.tsv"
  python3 - "$registry_path" "$AGENIC_PROJECT_NAME" "$AGENIC_PROJECT_BRANCH" "$AGENIC_PROJECT_ROOT" "$AGENIC_PROJECT_PONY_WORK_DIR" "$AGENIC_PROJECT_PONY_LAUNCH_PROMPTS_DIR" "$AGENIC_PROJECT_PONY_WORKTREES_DIR" <<'PY'
import csv
import io
import sys
from pathlib import Path

(
    registry_path,
    project_name,
    project_branch,
    project_root,
    work_dir,
    prompts_dir,
    worktrees_dir,
) = sys.argv[1:]

path = Path(registry_path)
fieldnames = [
    "assignment_id",
    "worker_label",
    "personality",
    "repo",
    "branch",
    "worktree",
    "workfile",
    "promptfile",
    "scope",
]
managed = {
    "aj": ("AJ", "APPLEJACK", f"pony/aj/{project_branch}", f"{worktrees_dir}/aj", f"{work_dir}/aj.md", f"{prompts_dir}/aj.txt", "unassigned"),
    "pinkie": ("Pinkie", "PINKIE_PIE", f"pony/pinkie/{project_branch}", f"{worktrees_dir}/pinkie", f"{work_dir}/pinkie.md", f"{prompts_dir}/pinkie.txt", "unassigned"),
    "fs": ("FS", "FLUTTERSHY", f"pony/fs/{project_branch}", f"{worktrees_dir}/fs", f"{work_dir}/fs.md", f"{prompts_dir}/fs.txt", "unassigned"),
    "rarity": ("Rarity", "RARITY", f"pony/rarity/{project_branch}", f"{worktrees_dir}/rarity", f"{work_dir}/rarity.md", f"{prompts_dir}/rarity.txt", "unassigned"),
    "rd": ("RD", "RAINBOW_DASH", f"pony/rd/{project_branch}", f"{worktrees_dir}/rd", f"{work_dir}/rd.md", f"{prompts_dir}/rd.txt", "unassigned"),
    "spike": ("Spike", "SPIKE", f"pony/spike/{project_branch}", f"{worktrees_dir}/spike", f"{work_dir}/spike.md", f"{prompts_dir}/spike.txt", "unassigned"),
    "twi": ("Twilight", "TWILIGHT_SPARKLE", project_branch, project_root, f"{work_dir}/coordinator-twi.md", f"{prompts_dir}/twi.txt", "coordinate the team"),
}

if project_branch == "no-git-branch":
    managed = {
        key: (
            label,
            personality,
            project_branch,
            project_root,
            workfile,
            promptfile,
            scope,
        )
        for key, (label, personality, _branch, _worktree, workfile, promptfile, scope) in managed.items()
    }

rows = []
if path.exists():
    rows = list(csv.DictReader(path.open(encoding="utf-8"), delimiter="\t"))

by_id = {row["assignment_id"]: row for row in rows}
ordered = []
for assignment_id in ["aj", "pinkie", "fs", "rarity", "rd", "spike", "twi"]:
    label, personality, branch, worktree, workfile, promptfile, default_scope = managed[assignment_id]
    row = by_id.get(assignment_id, {})
    scope = row.get("scope") or default_scope
    ordered.append(
        {
            "assignment_id": assignment_id,
            "worker_label": label,
            "personality": personality,
            "repo": project_name,
            "branch": branch,
            "worktree": worktree,
            "workfile": workfile,
            "promptfile": promptfile,
            "scope": scope,
        }
    )

buf = io.StringIO()
writer = csv.DictWriter(buf, fieldnames=fieldnames, delimiter="\t", lineterminator="\n")
writer.writeheader()
writer.writerows(ordered)
path.write_text(buf.getvalue(), encoding="utf-8")
PY
}

write_mailbox_if_missing() {
  local slug="${1:?missing worker slug}"
  local upper_name
  upper_name="$(printf '%s' "$slug" | tr '[:lower:]' '[:upper:]')"
  write_file_if_missing "$AGENIC_TEAM_COORDINATION_DIR/${slug}.mailbox.md" "$(cat <<EOF
# ${upper_name} MAILBOX

## Pending Items
- none

EOF
)"
}

write_file_if_missing "$AGENIC_PROJECT_PONY_DIR/README.md" "$(cat <<EOF
# pony

Project-local pony runtime state for $AGENIC_PROJECT_NAME.

This directory is generated by:
$agenic_root/scripts/bootstrap-project.sh
EOF
)"

write_file_if_missing "$AGENIC_PROJECT_PONY_RUNTIME_STATE_PATH" "$(cat <<EOF
idle
EOF
)"

write_file_if_missing "$AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_PATH" ""
write_file_if_missing "$AGENIC_PROJECT_PONY_RUNTIME_PENDING_NOTICE_SEEN_PATH" ""
write_file_if_missing "$AGENIC_PROJECT_PONY_RUNTIME_ACTIVE_PROMPT_PATH" ""
write_file_if_missing "$AGENIC_PROJECT_PONY_RUNTIME_DRAFT_PATH" ""

write_project_config_if_missing

for prompt_template in "$source_pony_launch_prompts_dir"/*.txt; do
  write_managed_file "$AGENIC_PROJECT_PONY_LAUNCH_PROMPTS_DIR/$(basename "$prompt_template")" "$(cat "$prompt_template")"
done

if [[ -d "$source_pony_root/assets" ]] && [[ "$source_pony_root/assets" != "$AGENIC_PROJECT_PONY_ASSETS_DIR" ]]; then
  cp -R "$source_pony_root/assets/." "$AGENIC_PROJECT_PONY_ASSETS_DIR/"
fi

if ! is_agenic_source_project && [[ -d "$agenic_root/vendor/prompt_toolkit" ]]; then
  mkdir -p "$AGENIC_PROJECT_PONY_VENDOR_DIR/prompt_toolkit"
  cp -R "$agenic_root/vendor/prompt_toolkit/." "$AGENIC_PROJECT_PONY_VENDOR_DIR/prompt_toolkit/"
fi

if ! is_agenic_source_project; then
  ensure_git_exclude_rule "/pony/"
fi

for managed_bin in codex-prompt-style.sh ponyalert ponydone codex-restart; do
  if [[ -f "$source_pony_bin_dir/$managed_bin" ]]; then
    write_managed_executable "$AGENIC_PROJECT_PONY_BIN_DIR/$managed_bin" "$(cat "$source_pony_bin_dir/$managed_bin")"
  fi
done

for managed_script in \
  codex-tmux-monitor.sh \
  pony-paths.sh \
  enter-twi-session.sh \
  enter-worker-and-codex.sh \
  enter-worker-from-prompt-file.sh \
  enter-worker-shell.sh \
  launch-debug.sh \
  launch-worker.sh \
  pony-line-editor.py \
  pony-session-host.py \
  resolve-system-root.sh \
  start-session.sh \
  warm-codex-tui.sh \
  watch-twi.sh \
  worker-postflight.sh \
  worker-preflight.sh
do
  if [[ -f "$source_pony_scripts_dir/$managed_script" ]]; then
    write_managed_executable "$AGENIC_PROJECT_PONY_SCRIPTS_DIR/$managed_script" "$(cat "$source_pony_scripts_dir/$managed_script")"
  fi
done

write_managed_file "$AGENIC_PROJECT_PONY_SCRIPTS_DIR/pony.zsh.support.zsh" "$(cat "$source_pony_scripts_dir/pony.zsh.support.zsh")"
write_managed_executable "$AGENIC_PROJECT_PONY_SCRIPTS_DIR/launch-in-pony-shell.sh" "$(cat "$source_pony_scripts_dir/launch-in-pony-shell.sh")"
write_managed_executable "$AGENIC_PROJECT_PONY_SCRIPTS_DIR/queue-runtime.sh" "$(cat "$source_pony_scripts_dir/queue-runtime.sh")"

if ! is_agenic_source_project; then
  write_managed_executable "$AGENIC_PROJECT_PONY_BIN_DIR/codex-pony" "$(cat <<EOF
#!/usr/bin/env bash
set -euo pipefail
source_root="\$("$AGENIC_PROJECT_PONY_SCRIPTS_DIR/resolve-system-root.sh" "$AGENIC_PROJECT_ROOT")"
export AGENIC_PONY_SOURCE_ROOT="\$source_root"
exec "\$source_root/pony/bin/codex-pony" "\$@"
EOF
)"

  write_managed_executable "$AGENIC_PROJECT_PONY_SCRIPTS_DIR/start-session.sh" "$(cat <<EOF
#!/usr/bin/env bash
set -euo pipefail
project_root="$AGENIC_PROJECT_ROOT"
resolver="\$project_root/pony/scripts/resolve-system-root.sh"
source_root="\$("\$resolver" "\$project_root")"
export AGENIC_PONY_SOURCE_ROOT="\$source_root"
exec "\$source_root/pony/scripts/start-session.sh" "\${1:?missing personality}" "\$project_root"
EOF
)"
fi

write_shell_launcher_if_missing "$AGENIC_PROJECT_PONY_BIN_DIR/pony-team-twi" "TWILIGHT_SPARKLE"
if ! is_agenic_source_project; then
  write_shell_launcher_if_missing "$AGENIC_PROJECT_PONY_BIN_DIR/pony-aj" "APPLEJACK"
  write_managed_executable "$AGENIC_PROJECT_PONY_BIN_DIR/pony-team" "$(cat <<EOF
#!/usr/bin/env bash
set -euo pipefail
cd "$AGENIC_PROJECT_ROOT"
printf '%s\n' "Project-local launcher set:"
printf '%s\n' "- ./pony/bin/pony-team-twi"
if [[ -x ./pony/bin/pony-aj ]]; then
  printf '%s\n' "- ./pony/bin/pony-aj"
fi
printf '%s\n' ""
printf '%s\n' "Warp users can use the generated project-specific launch configurations under:"
printf '%s\n' "./pony/launch.configs"
EOF
)"
else
  remove_if_exists "$AGENIC_PROJECT_PONY_BIN_DIR/pony-aj"
  remove_if_exists "$AGENIC_PROJECT_PONY_BIN_DIR/pony-team"
fi

for slug in aj pinkie fs rarity rd spike; do
  ensure_worker_worktree "$slug"
  sync_worker_worktree_runtime "$slug"
done

sync_assignment_registry

for slug in aj pinkie fs rarity rd spike twi; do
  write_workfile_if_missing "$slug"
  write_status_if_missing "$slug"
  heal_status_assignment_if_default "$slug"
  write_mailbox_if_missing "$slug"
done

write_file_if_missing "$AGENIC_TEAM_COORDINATION_DIR/twi.todo.md" "$(cat <<EOF
# TWILIGHT TODO

Generated: blank

No pending Twilight questions or decisions.
EOF
)"

write_file_if_missing "$AGENIC_TEAM_COORDINATION_DIR/twi.decisions.md" "$(cat <<EOF
# TWILIGHT DECISIONS

## Active Decisions
- none
EOF
)"

write_file_if_missing "$AGENIC_TEAM_COORDINATION_DIR/twi.event.stream.history.md" "$(cat <<EOF
# TWILIGHT EVENT STREAM HISTORY

## Current State
- pending_review_needed_content: none
EOF
)"

write_file_if_missing "$AGENIC_TEAM_COORDINATION_DIR/multi.agent.control.md" "$(cat <<EOF
# MULTI AGENT CONTROL

Blank project-local coordination state for $AGENIC_PROJECT_NAME on $AGENIC_PROJECT_BRANCH.
EOF
)"

write_file_if_missing "$AGENIC_TEAM_COORDINATION_DIR/twi.review-needed" ""

write_file_if_missing "$AGENIC_PROJECT_PONY_LINUX_SHELL_MARKER" ""

cat <<EOF
Bootstrapped project-local pony state.
- project_root: $AGENIC_PROJECT_ROOT
- branch: $AGENIC_PROJECT_BRANCH
- pony_root: $AGENIC_PROJECT_PONY_DIR
- shell_launchers: $AGENIC_PROJECT_PONY_BIN_DIR/pony-team-twi$(if ! is_agenic_source_project; then printf ', %s, %s' "$AGENIC_PROJECT_PONY_BIN_DIR/pony-team" "$AGENIC_PROJECT_PONY_BIN_DIR/pony-aj"; fi)
EOF
