#!/usr/bin/env python3
"""Relay terminal output while retaining a private, rolling restart transcript."""

from __future__ import annotations

import os
import re
import sys
from collections import deque
from pathlib import Path


MAX_LINES = 1000
ANSI_ESCAPE = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))")


def write_snapshot(path: Path, lines: deque[str], partial: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    content = "\n".join(lines)
    if partial:
        content = f"{content}\n{partial}" if content else partial
    if content:
        content += "\n"
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(content, encoding="utf-8")
    temporary.chmod(0o600)
    temporary.replace(path)


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: output-tail.py OUTPUT_PATH")

    output_path = Path(sys.argv[1])
    os.umask(0o077)
    lines: deque[str] = deque(maxlen=MAX_LINES)
    partial = ""

    while chunk := sys.stdin.buffer.read1(8192):
        sys.stdout.buffer.write(chunk)
        sys.stdout.buffer.flush()
        text = ANSI_ESCAPE.sub("", chunk.decode("utf-8", errors="replace")).replace("\r", "")
        partial += text
        complete, separator, partial = partial.rpartition("\n")
        if separator:
            lines.extend(complete.split("\n"))
            write_snapshot(output_path, lines, partial)

    write_snapshot(output_path, lines, partial)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
