#!/usr/bin/env python3
"""PostToolUse hook: flag long comment blocks that an edit just introduced.

The comment policy in CLAUDE.md is easy to agree with and easy to drift from,
so this reports the drift instead of trusting self-assessment. It only looks at
comment runs containing a line this edit added, and never blocks the edit.
"""

import json
import os
import re
import subprocess
import sys
from typing import Iterable, NamedTuple, Optional

# Prose lines, not total lines: a /** ... */ wrapper adds two lines of syntax
# that say nothing, and counting them would flag one-line javadoc.
MAX_PROSE = 2

# A file's opening block (license, provenance, usage) is exempt: it documents
# the file rather than a decision in the code.
HEADER_LINES = 4


class Syntax(NamedTuple):
    line: tuple[str, ...]
    block: tuple[tuple[str, str], ...]


HASH = Syntax(("#",), ())
SLASH = Syntax(("//",), (("/*", "*/"),))
DASH = Syntax(("--",), (("--[[", "]]"),))
SQL = Syntax(("--",), (("/*", "*/"),))
POWERSHELL = Syntax(("#",), (("<#", "#>"),))
RUBY = Syntax(("#",), (("=begin", "=end"),))

# Extension groups as plain strings so a formatter can't explode them into one
# entry per line.
C_LIKE = """.c .h .cc .cpp .cxx .c++ .hh .hpp .hxx .inl .ipp .cu .cuh .m .mm
    .metal .glsl .vert .frag .comp .hlsl .proto .fbs
    .js .mjs .cjs .jsx .ts .mts .cts .tsx .css .scss .less
    .java .kt .kts .scala .swift .rs .go .zig .cs .php .dart .groovy .gradle
    .v .sv .vhd .jsonc .json5"""

HASH_LIKE = """.sh .bash .zsh .ksh .fish .py .pyi .pyx .pl .pm .tcl .r .jl .nim
    .ex .exs .cmake .yaml .yml .toml .tf .hcl .bzl .bazel .star .mk .just
    .conf .service .gitconfig .env"""

# Build files and dotfiles, matched whole because they have no extension.
HASH_NAMES = """BUILD BUILD.bazel WORKSPACE WORKSPACE.bazel MODULE.bazel Makefile
    GNUmakefile justfile Justfile CMakeLists.txt Dockerfile Containerfile
    Vagrantfile Gemfile Rakefile Doxyfile PKGBUILD .bashrc .zshrc .profile
    .gitignore .dockerignore .editorconfig"""

BY_EXT: dict[str, Syntax] = {
    **{ext: SLASH for ext in C_LIKE.split()},
    **{ext: HASH for ext in HASH_LIKE.split()},
    ".lua": DASH,
    ".sql": SQL,
    ".hs": Syntax(("--",), (("{-", "-}"),)),
    ".ml": Syntax((), (("(*", "*)"),)),
    ".vim": Syntax(('"',), ()),
    ".ps1": POWERSHELL,
    ".psm1": POWERSHELL,
    ".rb": RUBY,
    ".erb": RUBY,
}

BY_NAME: dict[str, Syntax] = {name: HASH for name in HASH_NAMES.split()}

MARKER_RE = re.compile(
    r'^\s*(?:/\*+|\*+/|\*+|//+|#+|--+|;+|"|<#|#>|=begin|=end|\{-|-\}|\(\*|\*\))'
)


def syntax_for(path: str) -> Optional[Syntax]:
    name = os.path.basename(path)
    if name in BY_NAME:
        return BY_NAME[name]
    _, ext = os.path.splitext(name)
    return BY_EXT.get(ext.lower())


def added_lines(path: str) -> Optional[set[int]]:
    """Line numbers this working tree adds to `path`, or None if git can't say."""
    # -C the file's own directory: the hook inherits the session's cwd, so a
    # file in any other repo would look untracked and every line would count.
    repo = os.path.dirname(os.path.abspath(path)) or "."
    try:
        tracked = subprocess.run(
            ["git", "-C", repo, "ls-files", "--error-unmatch", path],
            capture_output=True,
            timeout=5,
        )
        if tracked.returncode != 0:
            return None  # untracked: the whole file is new, so every line counts
        diff = subprocess.run(
            ["git", "-C", repo, "diff", "-U0", "HEAD", "--", path],
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


def starts_line_comment(text: str, syntax: Syntax) -> bool:
    return any(text.startswith(prefix) for prefix in syntax.line)


def comment_map(lines: Iterable[str], syntax: Syntax) -> dict[int, str]:
    """Comment-only line numbers mapped to their prose (markers stripped)."""
    found: dict[int, str] = {}
    closing: Optional[str] = None

    for number, raw in enumerate(lines, start=1):
        text = raw.strip()

        if closing is not None:
            found[number] = strip_markers(text)
            end = text.find(closing)
            if end >= 0:
                tail = text[end + len(closing) :].strip()
                closing = None
                if tail and not starts_line_comment(tail, syntax):
                    del found[number]  # code resumes on this line
            continue

        opener = earliest_opener(text, syntax)
        # An opener is checked before the line prefix because lua's --[[ starts
        # with its own line prefix --, so prefix-first would never see the block.
        if opener is None or text[: opener[0]].strip():
            if text and starts_line_comment(text, syntax):
                found[number] = strip_markers(text)
                continue
        if opener is None:
            continue

        at, (open_tag, close_tag) = opener
        if not text[:at].strip():
            found[number] = strip_markers(text)
        end = text.find(close_tag, at + len(open_tag))
        if end < 0:
            closing = close_tag
            continue
        tail = text[end + len(close_tag) :].strip()
        if tail and not starts_line_comment(tail, syntax) and number in found:
            del found[number]

    return found


def earliest_opener(text: str, syntax: Syntax) -> Optional[tuple[int, tuple[str, str]]]:
    best: Optional[tuple[int, tuple[str, str]]] = None
    for open_tag, close_tag in syntax.block:
        at = text.find(open_tag)
        if at >= 0 and (best is None or at < best[0]):
            best = (at, (open_tag, close_tag))
    return best


def strip_markers(text: str) -> str:
    prose = text
    while True:
        trimmed = MARKER_RE.sub("", prose, count=1)
        if trimmed == prose:
            break
        prose = trimmed
    return prose.strip()


def long_runs(
    marked: dict[int, str], total: int, touched: Optional[set[int]]
) -> list[tuple[int, int]]:
    """(start_line, prose_lines) for over-long runs this edit is responsible for."""
    flagged: list[tuple[int, int]] = []
    start: Optional[int] = None
    for number in range(1, total + 2):
        if number in marked:
            if start is None:
                start = number
            continue
        if start is None:
            continue
        span = range(start, number)
        prose = sum(1 for n in span if marked[n])
        if prose > MAX_PROSE and start > HEADER_LINES:
            if touched is None or any(n in touched for n in span):
                flagged.append((start, prose))
        start = None
    return flagged


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    path = payload.get("tool_input", {}).get("file_path") or ""
    syntax = syntax_for(path) if path else None
    if syntax is None:
        return 0
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            lines = handle.read().splitlines()
    except OSError:
        return 0

    flagged = long_runs(comment_map(lines, syntax), len(lines), added_lines(path))
    if not flagged:
        return 0

    where = ", ".join(
        f"line {start} ({prose} lines of prose)" for start, prose in flagged
    )
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PostToolUse",
                    "additionalContext": (
                        f"Comment policy check on {path}: comment block(s) over "
                        f"{MAX_PROSE} lines at {where}. Re-read each one. Keep it only "
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
