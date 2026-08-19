#!/usr/bin/env python3
"""PostToolUse hook: flag long comment blocks that an edit just introduced.

The comment policy in CLAUDE.md is easy to agree with and easy to drift from,
so this reports the drift instead of trusting self-assessment. It only looks at
comment runs containing a line this edit added, and never blocks the edit.
"""

import json
import re
import subprocess
import sys
from typing import Optional

# Runs longer than this are reported. Not a prohibition -- a real gotcha may
# need the space; the point is to force a second look before it stands.
MAX_RUN = 2

# A file's opening block (license, provenance, usage) is exempt: it documents
# the file rather than a decision in the code.
HEADER_LINES = 4

COMMENT_RE = re.compile(r"^\s*(#|//|--|;|/\*|\*(?!/))")
CODE_EXT = {
    ".sh",
    ".bash",
    ".zsh",
    ".py",
    ".c",
    ".h",
    ".cc",
    ".cpp",
    ".hpp",
    ".cu",
    ".zig",
    ".lua",
    ".rs",
    ".go",
    ".js",
    ".ts",
    ".java",
    ".sql",
    ".vim",
}


def added_lines(path: str) -> Optional[set[int]]:
    """Line numbers this working tree adds to `path`, or None if git can't say."""
    try:
        tracked = subprocess.run(
            ["git", "ls-files", "--error-unmatch", path],
            capture_output=True,
            timeout=5,
        )
        if tracked.returncode != 0:
            return None  # untracked: the whole file is new, so every line counts
        diff = subprocess.run(
            ["git", "diff", "-U0", "HEAD", "--", path],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if diff.returncode != 0:
        return None

    added: set[int] = set()
    for line in diff.stdout.splitlines():
        header = re.match(r"^@@ -\S+ \+(\d+)(?:,(\d+))? @@", line)
        if header:
            start = int(header.group(1))
            count = 1 if header.group(2) is None else int(header.group(2))
            added.update(range(start, start + count))
    return added


def long_runs(lines: list[str], touched: Optional[set[int]]) -> list[tuple[int, int]]:
    """(start_line, length) of over-long comment runs the edit is responsible for."""
    runs: list[tuple[int, int]] = []
    start: Optional[int] = None
    for idx, line in enumerate(lines, start=1):
        if COMMENT_RE.match(line):
            if start is None:
                start = idx
            continue
        if start is not None:
            runs.append((start, idx - start))
            start = None
    if start is not None:
        runs.append((start, len(lines) + 1 - start))

    flagged = []
    for begin, length in runs:
        if length <= MAX_RUN or begin <= HEADER_LINES:
            continue
        span = range(begin, begin + length)
        if touched is None or any(n in touched for n in span):
            flagged.append((begin, length))
    return flagged


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    path = payload.get("tool_input", {}).get("file_path") or ""
    if not path or not any(path.endswith(ext) for ext in CODE_EXT):
        return 0
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            lines = handle.read().splitlines()
    except OSError:
        return 0

    flagged = long_runs(lines, added_lines(path))
    if not flagged:
        return 0

    where = ", ".join(f"line {begin} ({length} lines)" for begin, length in flagged)
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PostToolUse",
                    "additionalContext": (
                        f"Comment policy check on {path}: comment block(s) over "
                        f"{MAX_RUN} lines at {where}. Re-read each one. Keep it only "
                        "if it names a constraint that would otherwise be "
                        "rediscovered the hard way; if it argues for the decision, "
                        "cut it to the constraint and put the argument in the commit "
                        "message."
                    ),
                }
            }
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
