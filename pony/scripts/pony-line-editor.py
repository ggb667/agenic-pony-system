#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path


def configure_import_path(script_path: Path) -> None:
    project_vendor = script_path.resolve().parents[1] / "vendor"
    if str(project_vendor) not in sys.path:
        sys.path.insert(0, str(project_vendor))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--personality", required=True)
    parser.add_argument("--workfile", required=True)
    parser.add_argument("--draft-path", required=True)
    parser.add_argument("--notice-path", required=True)
    parser.add_argument("--history-path", required=True)
    parser.add_argument("--result-path", required=True)
    return parser.parse_args()


def prompt_label_for(personality: str) -> str:
    labels = {
        "TWILIGHT_SPARKLE": "✶ Twilight",
        "APPLEJACK": "🍎 Applejack",
        "PINKIE_PIE": "🎈 Pinkie",
        "RARITY": "💎 Rarity",
        "FLUTTERSHY": "🦋 Fluttershy",
        "RAINBOW_DASH": "⚡ Rainbow Dash",
        "SPIKE": "🐲 Spike",
    }
    return labels.get(personality, personality)


def main() -> int:
    script_path = Path(__file__)
    configure_import_path(script_path)

    from prompt_toolkit import PromptSession
    from prompt_toolkit.history import FileHistory
    from prompt_toolkit.styles import Style

    args = parse_args()
    draft_path = Path(args.draft_path)
    notice_path = Path(args.notice_path)
    history_path = Path(args.history_path)
    result_path = Path(args.result_path)

    draft_path.parent.mkdir(parents=True, exist_ok=True)
    history_path.parent.mkdir(parents=True, exist_ok=True)
    result_path.parent.mkdir(parents=True, exist_ok=True)

    draft_text = draft_path.read_text() if draft_path.exists() else ""
    notice_text = notice_path.read_text().strip() if notice_path.exists() else ""

    style = Style.from_dict(
        {
            "prompt": "bold",
            "toolbar": "reverse",
        }
    )

    toolbar = notice_text or "Enter submits to the parked pony session. Ctrl-C leaves the session parked."
    prompt_label = f"{prompt_label_for(args.personality)} > "

    session = PromptSession(history=FileHistory(str(history_path)))
    try:
      text = session.prompt(
          [("class:prompt", prompt_label)],
          default=draft_text,
          style=style,
          bottom_toolbar=toolbar,
          multiline=True,
      )
    except KeyboardInterrupt:
      return 130
    except EOFError:
      return 130

    draft_path.write_text(text)
    result_path.write_text(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())