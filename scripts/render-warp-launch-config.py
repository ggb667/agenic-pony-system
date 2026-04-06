#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shlex
from pathlib import Path


PONIES = [
    ("twi", "TWI", "magenta", "TWILIGHT_SPARKLE"),
    ("aj", "AJ", "yellow", "APPLEJACK"),
    ("pinkie", "Pinkie", "red", "PINKIE_PIE"),
    ("fs", "FS", "green", "FLUTTERSHY"),
    ("rarity", "Rarity", "white", "RARITY"),
    ("rd", "RD", "cyan", "RAINBOW_DASH"),
    ("spike", "Spike", "blue", "SPIKE"),
]


def render_tab(agenic_root: Path, project_root: Path, slug: str, title: str, color: str, personality: str, focused: bool) -> list[str]:
    command = (
        f"zsh -lc 'cd {shlex.quote(str(project_root))} && "
        f"{shlex.quote(str(agenic_root / 'pony/scripts/start-session.sh'))} "
        f"{shlex.quote(personality)} {shlex.quote(str(project_root))}'"
    )
    lines = [
        f"      - title: {title}",
        f"        color: {color}",
        "        layout:",
        f"          cwd: {project_root}",
    ]
    if focused:
        lines.append("          is_focused: true")
    lines.extend(
        [
            "          commands:",
            f'            - exec: "{command}"',
        ]
    )
    return lines


def render_config(agenic_root: Path, project_root: Path, mode: str) -> str:
    project_name = project_root.name
    lines = [
        "# AGENIC_PONYSHOW: true",
        "# AGENIC_PONYSHOW_ROLE: baseline_config",
        f"# Project-local state root: {project_root}/.agenic-pony",
        f"name: Agenic Pony {project_name}",
        "active_window_index: 0",
        "windows:",
        "  - active_tab_index: 0",
        "    tabs:",
    ]
    for slug, title, color, personality in PONIES:
        if mode == "twi" and slug != "twi":
            continue
        lines.extend(render_tab(agenic_root, project_root, slug, title, color, personality, focused=slug == "twi"))
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--agenic-root", required=True)
    parser.add_argument("--project-root", required=True)
    parser.add_argument("--mode", choices=("team", "twi"), default="team")
    args = parser.parse_args()

    agenic_root = Path(args.agenic_root).resolve()
    project_root = Path(args.project_root).resolve()
    print(render_config(agenic_root, project_root, args.mode), end="")


if __name__ == "__main__":
    main()
