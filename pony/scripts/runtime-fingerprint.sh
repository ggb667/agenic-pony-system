#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

cd "$repo_root"

python3 - <<'PY'
from hashlib import sha256
from pathlib import Path

repo_root = Path.cwd()
include_roots = [
    repo_root / "pony/bin",
    repo_root / "pony/launch.prompts",
    repo_root / "pony/scripts",
]
include_files = [
    repo_root / "scripts/bootstrap-project.sh",
    repo_root / "scripts/install-project.sh",
]

paths = []
for root in include_roots:
    if root.exists():
        paths.extend(sorted(path for path in root.rglob("*") if path.is_file()))
for path in include_files:
    if path.exists():
        paths.append(path)

hasher = sha256()
for path in sorted(set(paths)):
    rel = path.relative_to(repo_root).as_posix().encode("utf-8")
    hasher.update(rel)
    hasher.update(b"\0")
    hasher.update(path.read_bytes())
    hasher.update(b"\0")

print(hasher.hexdigest())
PY
