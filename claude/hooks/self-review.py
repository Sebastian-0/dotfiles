#!/usr/bin/env python3
"""PreToolUse hook: refuse to push or merge work no independent reviewer has seen.

Self-assessment is the thing being checked here, so the state lives in git
rather than in the session: the hook compares the branch's whole diff against
the ones last recorded as reviewed. Run with --mark to record the current diff,
which is what the self-review skill does once a review has been addressed.

The gate sits on the commands that hand work to someone else rather than on the
end of every turn, which fires while the work is still being written.
"""

import hashlib
import json
import os
import re
import subprocess
import sys
from typing import Optional

STATE_FILE = "claude-self-review"

# Marks from other branches and worktrees are kept so that switching between
# them does not ask for the same review again.
HISTORY = 20

MAX_UNTRACKED = 200
MAX_UNTRACKED_BYTES = 256 * 1024

GATED_COMMANDS = (
    re.compile(r"\bgit\b[^&|;]*\bpush(?![-\w])"),
    re.compile(r"\bgit\b[^&|;]*\bmerge(?![-\w])"),
    re.compile(r"\bgh\b[^&|;]*\bpr\s+(?:create|merge)(?![-\w])"),
)

BASE_CANDIDATES = (
    "refs/remotes/origin/main",
    "refs/remotes/origin/master",
    "refs/remotes/origin/trunk",
    "refs/remotes/origin/develop",
    "refs/heads/main",
    "refs/heads/master",
    "refs/heads/trunk",
)


def git(repo: str, *args: str) -> Optional[str]:
    try:
        done = subprocess.run(
            ["git", "-C", repo, *args],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return done.stdout.strip() if done.returncode == 0 else None


def repo_root(path: str) -> str:
    """Every command runs from the top level: `ls-files` only reports below its cwd."""
    return git(path, "rev-parse", "--show-toplevel") or path


def base_refs(repo: str) -> list[str]:
    origin_head = git(repo, "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD")
    listed = git(repo, "for-each-ref", "--format=%(refname)", *BASE_CANDIDATES) or ""
    existing = set(listed.split())
    ordered = [ref for ref in BASE_CANDIDATES if ref in existing]
    # The branch's own upstream comes last: once the branch is pushed it points
    # at HEAD, and taking it as the base would hide everything already pushed.
    upstream = git(repo, "rev-parse", "--symbolic-full-name", "@{upstream}")
    refs: list[str] = []
    for ref in [origin_head, *ordered, upstream]:
        if ref and ref not in refs:
            refs.append(ref)
    return refs


def base_commit(repo: str) -> Optional[str]:
    """Commit this branch grew out of, so committed work still counts as unreviewed."""
    head = git(repo, "rev-parse", "HEAD")
    for ref in base_refs(repo):
        commit = git(repo, "merge-base", ref, "HEAD")
        if not commit:
            continue
        # A local branch sitting on HEAD says nothing about what is new here,
        # unlike a remote one, which marks what has already left this machine.
        if commit == head and not ref.startswith("refs/remotes/"):
            continue
        return commit
    return None


def untracked(repo: str) -> str:
    """Path and content of every new file, which no diff against a commit shows."""
    listed = git(
        repo,
        "-c",
        "core.quotePath=false",
        "ls-files",
        "-z",
        "--others",
        "--exclude-standard",
    )
    names = sorted(name for name in (listed or "").split("\0") if name)
    if not names:
        return ""
    # The count is hashed as well, so a file arriving past the cap still shows up.
    parts = [f"{len(names)} untracked"]
    for name in names[:MAX_UNTRACKED]:
        full = os.path.join(repo, name)
        try:
            size = os.path.getsize(full)
            with open(full, "rb") as handle:
                body = handle.read(MAX_UNTRACKED_BYTES)
        except OSError:
            size, body = -1, b""
        parts.append(f"{name}\n{size}\n{hashlib.sha256(body).hexdigest()}")
    return "\n".join(parts)


def digest(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", "replace")).hexdigest()


def fingerprint(repo: str) -> Optional[str]:
    """Hash of everything the branch changes, or None when it changes nothing."""
    head = git(repo, "rev-parse", "HEAD")
    if head is None:
        return combine(git(repo, "diff", "--cached") or "", untracked(repo))

    base = base_commit(repo)
    diff = git(repo, "diff", base or head)
    if diff is None:
        # git could not answer, so nothing here is known to have been reviewed.
        return digest(f"git unavailable\n{head}")
    if base:
        return combine(diff, untracked(repo))
    # No base ref: a commit cannot be told apart from the branch it sits on, so
    # the commit counts too.
    return digest("\n".join([head, diff, untracked(repo)]))


def combine(*parts: str) -> Optional[str]:
    joined = "\n".join(part for part in parts if part)
    return digest(joined) if joined else None


def state_path(repo: str) -> Optional[str]:
    git_dir = git(repo, "rev-parse", "--path-format=absolute", "--git-common-dir")
    return os.path.join(git_dir, STATE_FILE) if git_dir else None


def reviewed(repo: str) -> list[str]:
    path = state_path(repo)
    if path is None:
        return []
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            return handle.read().split()
    except OSError:
        return []


def mark(repo: str) -> int:
    path = state_path(repo)
    if path is None:
        print(f"{repo} is not a git repository", file=sys.stderr)
        return 1
    current = fingerprint(repo)
    if current is None:
        print("Nothing to record: this branch changes nothing")
        return 0
    kept = [current] + [old for old in reviewed(repo) if old != current]
    staging = f"{path}.new"
    try:
        with open(staging, "w", encoding="utf-8") as handle:
            handle.write("\n".join(kept[:HISTORY]) + "\n")
        os.replace(staging, path)
    except OSError as error:
        print(f"could not write {path}: {error}", file=sys.stderr)
        return 1
    print(f"Recorded the current diff as reviewed in {path}")
    return 0


def gated(command: str) -> bool:
    return any(pattern.search(command) for pattern in GATED_COMMANDS)


def main() -> int:
    args = sys.argv[1:]
    if args:
        if args != ["--mark"]:
            print(f"usage: {os.path.basename(sys.argv[0])} [--mark]", file=sys.stderr)
            return 2
        return mark(repo_root(os.getcwd()))

    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    tool_input = payload.get("tool_input") or {}
    if payload.get("tool_name") != "Bash" or not gated(tool_input.get("command") or ""):
        return 0

    repo = repo_root(payload.get("cwd") or os.getcwd())
    current = fingerprint(repo)
    if current is None or current in reviewed(repo):
        return 0

    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": (
                        "This branch has changes that no independent reviewer has "
                        "seen: the diff differs from the ones recorded as reviewed. "
                        "Run the self-review skill on it, address what comes back, "
                        "and record it before handing the work on: python3 "
                        f"{os.path.abspath(__file__)} --mark"
                    ),
                }
            }
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
