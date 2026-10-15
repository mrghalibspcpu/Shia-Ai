"""Turn a `flutter test` log into one compact GitHub annotation.

GitHub truncates a workflow-command message at 4 KB, and the tail of a full
test log is the least useful part of it. This reads the log the CI run already
writes and lists the *failures* instead: the failing test's file and name,
followed by the expectation it broke.

Usage: `python3 scripts/flutter_test_digest.py /tmp/flutter-test.log`
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# `00:04 +113 -6: /path/to/test_x.dart: name of the test` (the `-6` is only
# there once something has failed).
PROGRESS_RE = re.compile(r"^\d\d:\d\d (?:\+\d+(?: -\d+)?):")
TIMESTAMP_RE = re.compile(r"^\d\d:\d\d ")

# How much of each failure block to keep, and how long the whole annotation may
# be (GitHub cuts at 4 KB; leave room for the title and the escaping).
BLOCK_LINES = 5
MAX_DETAIL = 3600


def _is_progress(line: str) -> bool:
    return bool(PROGRESS_RE.match(line.strip()))


def digest(log_text: str) -> str:
    """The failure blocks of a `flutter test --reporter expanded` log."""
    lines = [line.rstrip() for line in log_text.splitlines()]
    blocks: list[str] = []
    index = 0
    while index < len(lines):
        line = lines[index].strip()
        if "[E]" in line:
            block = [PROGRESS_RE.sub("", line).strip()]
            index += 1
            while (
                index < len(lines)
                and len(block) < BLOCK_LINES
                and lines[index].strip()
                and not _is_progress(lines[index])
            ):
                block.append(lines[index].strip())
                index += 1
            blocks.append(" / ".join(block))
        else:
            index += 1

    tail = next(
        (line.strip() for line in reversed(lines) if _is_progress(line)),
        "",
    )
    tail = TIMESTAMP_RE.sub("", tail)
    if not blocks:
        detail = "the test log held no failure blocks"
    else:
        detail = "\n".join(blocks)
    if tail:
        detail += "\n—\n" + tail
    if len(detail) > MAX_DETAIL:
        detail = detail[: MAX_DETAIL - 2] + " …"
    return detail


def annotate(log_path: str) -> str:
    detail = digest(Path(log_path).read_text(errors="replace"))
    failures = len([line for line in detail.splitlines() if "[E]" in line])
    escaped = detail.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    return f"::error title=Flutter tests failed ({failures})::{escaped}"


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: flutter_test_digest.py <flutter-test-log>", file=sys.stderr)
        return 2
    print(annotate(argv[1]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
