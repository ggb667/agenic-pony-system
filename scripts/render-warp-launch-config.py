#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shlex
from pathlib import Path


PONIES = [
    ("celestia", "Tia ☀︎", "yellow", "PRINCESS_CELESTIA_SOL_INVICTUS"),
    ("twi", "Twilight ✶", "magenta", "TWILIGHT_SPARKLE"),
    ("aj", "Applejack 🍎", "yellow", "APPLEJACK"),
    ("pinkie", "Pinkie 🎈", "red", "PINKIE_PIE"),
    ("fs", "Fluttershy 🦋", "green", "FLUTTERSHY"),
    ("rarity", "Rarity 💎", "white", "RARITY"),
    ("rd", "Rainbow Dash ⚡", "cyan", "RAINBOW_DASH"),
    ("spike", "Spike 🐲", "blue", "SPIKE"),
]

MODE_FILTERS = {
    "team": {"twi", "aj", "pinkie", "fs", "rarity", "rd", "spike"},
    "twi": {"twi"},
    "aj": {"aj"},
    "celestia": {"celestia"},
}


def render_tab(agenic_root: Path, project_root: Path, slug: str, title: str, color: str, personality: str, focused: bool) -> list[str]:
    launcher = project_root / "pony/scripts/launch-team-member.sh" if slug in MODE_FILTERS["team"] else project_root / "pony/scripts/launch-in-pony-shell.sh"
    command = shlex.quote(str(launcher)) + " " + shlex.quote(personality)
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


def display_project_name(project_root: Path) -> str:
    parts = project_root.name.replace("-", " ").replace("_", " ").split()
    rendered_parts = []
    for part in parts:
        if part.isupper():
            rendered_parts.append(part)
        else:
            rendered_parts.append(part.capitalize())
    return " ".join(rendered_parts)


def render_config(agenic_root: Path, project_root: Path, mode: str) -> str:
    project_name = display_project_name(project_root)
    if project_name.endswith("Pony System"):
        mode_titles = {
            "team": f"{project_name} Team",
            "twi": f"{project_name} Twi",
            "aj": f"{project_name} AJ",
            "celestia": f"{project_name} Celestia",
        }
    else:
        mode_titles = {
            "team": f"{project_name} Pony Team",
            "twi": f"{project_name} Pony Twi",
            "aj": f"{project_name} Pony AJ",
            "celestia": f"{project_name} Pony Celestia",
        }
    lines = [
        "# AGENIC_PONYSHOW: true",
        "# AGENIC_PONYSHOW_ROLE: baseline_config",
        f"# Project-local pony root: {project_root}/pony",
        f"name: {mode_titles[mode]}",
        "active_window_index: 0",
        "windows:",
        "  - active_tab_index: 0",
        "    tabs:",
    ]
    for slug, title, color, personality in PONIES:
        if slug not in MODE_FILTERS[mode]:
            continue
        if project_root == agenic_root and slug == "aj":
            continue
        lines.extend(render_tab(agenic_root, project_root, slug, title, color, personality, focused=slug in {"twi", "celestia"}))
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--agenic-root", required=True)
    parser.add_argument("--project-root", required=True)
    parser.add_argument("--mode", choices=("team", "twi", "aj", "celestia"), default="team")
    args = parser.parse_args()

    agenic_root = Path(args.agenic_root).resolve()
    project_root = Path(args.project_root).resolve()
    print(render_config(agenic_root, project_root, args.mode), end="")


if __name__ == "__main__":
    main()
