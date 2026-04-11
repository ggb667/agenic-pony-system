#!/usr/bin/env python3
from __future__ import annotations

import argparse


TITLE = "Princess Celestia Sol Invictus ☀"

OUTLINE_COLORS: dict[str, str] = {
    "outline_1": "#3D9DC4",
    "outline_2": "#48BAA9",
    "outline_3": "#7A9BDE",
    "outline_4": "#D085D0",
}

FILL_GRADIENTS: dict[str, tuple[str, str]] = {
    "fill_1": ("#44B1CE", "#8CDEE4"),
    "fill_2": ("#50CDA5", "#CBF5C0"),
    "fill_3": ("#80A4EE", "#AEDEFC"),
    "fill_4": ("#E599F2", "#F2C4FD"),
}

VARIANTS: dict[str, list[str]] = {
    "outline_cycle": list(OUTLINE_COLORS.values()),
    "outline_pairs": list(OUTLINE_COLORS.values()),
    "fill_cycle": [
        FILL_GRADIENTS["fill_1"][0],
        FILL_GRADIENTS["fill_1"][1],
        FILL_GRADIENTS["fill_2"][0],
        FILL_GRADIENTS["fill_2"][1],
        FILL_GRADIENTS["fill_3"][0],
        FILL_GRADIENTS["fill_3"][1],
        FILL_GRADIENTS["fill_4"][0],
        FILL_GRADIENTS["fill_4"][1],
    ],
    "gradient_1": [OUTLINE_COLORS["outline_1"], *FILL_GRADIENTS["fill_1"]],
    "gradient_2": [OUTLINE_COLORS["outline_2"], *FILL_GRADIENTS["fill_2"]],
    "gradient_3": [OUTLINE_COLORS["outline_3"], *FILL_GRADIENTS["fill_3"]],
    "gradient_4": [OUTLINE_COLORS["outline_4"], *FILL_GRADIENTS["fill_4"]],
    "celestia_line": [
        OUTLINE_COLORS["outline_1"],
        FILL_GRADIENTS["fill_1"][1],
        FILL_GRADIENTS["fill_1"][1],
        FILL_GRADIENTS["fill_1"][0],
        OUTLINE_COLORS["outline_1"],
        OUTLINE_COLORS["outline_2"],
        FILL_GRADIENTS["fill_2"][1],
        FILL_GRADIENTS["fill_2"][1],
        FILL_GRADIENTS["fill_2"][0],
        OUTLINE_COLORS["outline_2"],
        OUTLINE_COLORS["outline_3"],
        FILL_GRADIENTS["fill_3"][1],
        FILL_GRADIENTS["fill_3"][1],
        FILL_GRADIENTS["fill_3"][0],
        OUTLINE_COLORS["outline_3"],
        OUTLINE_COLORS["outline_4"],
        FILL_GRADIENTS["fill_4"][1],
        FILL_GRADIENTS["fill_4"][1],
        FILL_GRADIENTS["fill_4"][0],
        OUTLINE_COLORS["outline_4"],
    ],
    "full_palette": [
        OUTLINE_COLORS["outline_1"],
        *FILL_GRADIENTS["fill_1"],
        OUTLINE_COLORS["outline_2"],
        *FILL_GRADIENTS["fill_2"],
        OUTLINE_COLORS["outline_3"],
        *FILL_GRADIENTS["fill_3"],
        OUTLINE_COLORS["outline_4"],
        *FILL_GRADIENTS["fill_4"],
    ],
}


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    hex_value = value.lstrip("#")
    return tuple(int(hex_value[index : index + 2], 16) for index in (0, 2, 4))


def paint(text: str, palette: list[str]) -> str:
    parts: list[str] = []
    for index, char in enumerate(text):
        r, g, b = hex_to_rgb(palette[index % len(palette)])
        parts.append(f"\x1b[38;2;{r};{g};{b}m{char}")
    parts.append("\x1b[0m")
    return "".join(parts)


def paint_double_width(text: str, palette: list[str]) -> str:
    parts: list[str] = []
    for index, char in enumerate(text):
        r, g, b = hex_to_rgb(palette[(index // 2) % len(palette)])
        parts.append(f"\x1b[38;2;{r};{g};{b}m{char}")
    parts.append("\x1b[0m")
    return "".join(parts)


def print_variant(name: str, palette: list[str]) -> None:
    print(f"{name:18} {paint(TITLE, palette)}")


def print_double_variant(name: str, palette: list[str]) -> None:
    print(f"{name:18} {paint_double_width(TITLE, palette)}")


def print_palette() -> None:
    print("Restricted palette:")
    for name, color in OUTLINE_COLORS.items():
        print(f"  {name:10} {paint(color, [color])}")
    for name, (dark_fill, light_fill) in FILL_GRADIENTS.items():
        print(
            f"  {name:10} {paint(dark_fill, [dark_fill])} -> "
            f"{paint(light_fill, [light_fill])}"
        )
    print()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Preview per-character color variants for Princess Celestia Sol Invictus."
    )
    parser.add_argument(
        "--variant",
        choices=sorted(VARIANTS),
        help="Show one variant instead of the full list.",
    )
    args = parser.parse_args()

    print_palette()

    if args.variant:
        if args.variant == "outline_pairs":
            print_double_variant(args.variant, VARIANTS[args.variant])
            return 0
        print_variant(args.variant, VARIANTS[args.variant])
        return 0

    for name, palette in VARIANTS.items():
        if name == "outline_pairs":
            print_double_variant(name, palette)
            continue
        print_variant(name, palette)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
