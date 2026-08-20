#!/usr/bin/env python3
"""Stop hook: hold a turn that leaves the branch's code changes unreviewed.

Self-assessment is the thing being checked here, so the state lives in git
rather than in the session: the hook compares the branch's whole diff against
the ones last recorded as reviewed. Run with --mark to record the current diff,
which is what the self-review skill does once a review has been addressed.
"""

import hashlib
import json
import os
import subprocess
import sys
from typing import Optional

STATE_FILE = "claude-self-review"

# Marks from other branches and worktrees are kept so that switching between
# them does not ask for the same review again.
HISTORY = 20

MAX_UNTRACKED = 200
MAX_UNTRACKED_BYTES = 256 * 1024

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
            timeout=2,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return done.stdout.strip() if done.returncode == 0 else None


def base_refs(repo: str) -> list[str]:
    upstream = git(repo, "rev-parse", "--symbolic-full-name", "@{upstream}")
    origin_head = git(repo, "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD")
    listed = git(repo, "for-each-ref", "--format=%(refname)", *BASE_CANDIDATES) or ""
    existing = set(listed.split())
    ordered = [ref for ref in BASE_CANDIDATES if ref in existing]
    return [ref for ref in [upstream, origin_head, *ordered] if ref]


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
    listed = git(repo, "ls-files", "--others", "--exclude-standard")
    if not listed:
        return ""
    parts: list[str] = []
    for name in sorted(listed.splitlines())[:MAX_UNTRACKED]:
        try:
            with open(os.path.join(repo, name), "rb") as handle:
                body = handle.read(MAX_UNTRACKED_BYTES)
        except OSError:
            body = b""
        parts.append(f"{name}\n{hashlib.sha256(body).hexdigest()}")
    return "\n".join(parts)


def fingerprint(repo: str) -> Optional[str]:
    """Hash of everything the branch changes, or None when it changes nothing."""
    base = base_commit(repo)
    diff = git(repo, "diff", base if base else "HEAD") or ""
    tree = "\n".join(part for part in [diff, untracked(repo)] if part)
    if base:
        return digest(tree) if tree else None

    # No base ref: a commit cannot be told apart from the branch it sits on, so
    # the commit counts too -- except in a repo with no review recorded yet.
    if not tree and not reviewed(repo):
        return None
    return digest(f"{git(repo, 'rev-parse', 'HEAD')}\n{tree}")


def digest(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", "replace")).hexdigest()


def state_path(repo: str) -> Optional[str]:
    git_dir = git(repo, "rev-parse", "--path-format=absolute", "--git-common-dir")
    return os.path.join(git_dir, STATE_FILE) if git_dir else None


def reviewed(repo: str) -> list[str]:
    path = state_path(repo)
    if path is None:
        return []
    try:
        with open(path, encoding="utf-8") as handle:
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
    try:
        with open(path, "w", encoding="utf-8") as handle:
            handle.write("\n".join(kept[:HISTORY]) + "\n")
    except OSError as error:
        print(f"could not write {path}: {error}", file=sys.stderr)
        return 1
    print(f"Recorded the current diff as reviewed in {path}")
    return 0


def main() -> int:
    if "--mark" in sys.argv[1:]:
        return mark(os.getcwd())

    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0
    if payload.get("stop_hook_active"):
        return 0

    repo = payload.get("cwd") or os.getcwd()
    current = fingerprint(repo)
    if current is None or current in reviewed(repo):
        return 0

    print(
        json.dumps(
            {
                "decision": "block",
                "reason": (
                    "This branch has code changes that no independent reviewer has "
                    "seen: the diff differs from the ones recorded as reviewed. "
                    "Run the self-review skill on it before telling the user the "
                    "work is done. If a review genuinely does not apply -- nothing "
                    "but scratch files changed, or the user asked for something "
                    "throwaway -- say so in your reply, then record the diff and "
                    f"stop: python3 {os.path.abspath(__file__)} --mark"
                ),
            }
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
