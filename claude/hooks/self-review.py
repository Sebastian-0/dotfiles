#!/usr/bin/env python3
"""Stop hook: hold a turn that leaves the branch's code changes unreviewed.

Self-assessment is the thing being checked here, so the state lives in git
rather than in the session: the hook compares the branch's whole diff against
the one last recorded as reviewed. Run with --mark to record the current diff,
which is what the self-review skill does once a review has been addressed.
"""

import hashlib
import json
import os
import subprocess
import sys
from typing import Optional

STATE_FILE = "claude-self-review"

DEFAULT_BRANCHES = ("origin/main", "origin/master", "main", "master")


def git(repo: str, *args: str) -> Optional[str]:
    try:
        done = subprocess.run(
            ["git", "-C", repo, *args],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return done.stdout.strip() if done.returncode == 0 else None


def base_commit(repo: str) -> Optional[str]:
    """Commit this branch grew out of, so committed work still counts as unreviewed."""
    head = git(repo, "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD")
    remote_default = [head[len("refs/remotes/") :]] if head else []
    for ref in remote_default + list(DEFAULT_BRANCHES):
        merge_base = git(repo, "merge-base", ref, "HEAD")
        if merge_base:
            return merge_base
    return None


def fingerprint(repo: str) -> Optional[str]:
    """Hash of everything the branch changes, or None when it changes nothing."""
    base = base_commit(repo)
    # Untracked files stay out: scratch and log files would nudge forever.
    diff = git(repo, "diff", base) if base else git(repo, "diff", "HEAD")
    if not diff:
        return None
    return hashlib.sha256(diff.encode("utf-8", "replace")).hexdigest()


def state_path(repo: str) -> Optional[str]:
    git_dir = git(repo, "rev-parse", "--path-format=absolute", "--git-common-dir")
    return os.path.join(git_dir, STATE_FILE) if git_dir else None


def reviewed(repo: str) -> Optional[str]:
    path = state_path(repo)
    if path is None:
        return None
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read().strip()
    except OSError:
        return None


def mark(repo: str) -> int:
    path = state_path(repo)
    if path is None:
        print(f"{repo} is not a git repository", file=sys.stderr)
        return 1
    try:
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(f"{fingerprint(repo) or ''}\n")
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
    if current is None or current == reviewed(repo):
        return 0

    print(
        json.dumps(
            {
                "decision": "block",
                "reason": (
                    "This branch has code changes that no independent reviewer has "
                    "seen: the diff differs from the one last recorded as reviewed. "
                    "Run the self-review skill on it before telling the user the "
                    "work is done. If a review does not apply -- no source was "
                    "changed, or the user asked for something throwaway -- record "
                    "the diff instead and stop: python3 "
                    f"{os.path.abspath(__file__)} --mark"
                ),
            }
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
