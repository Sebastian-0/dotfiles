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
import shlex
import subprocess
import sys
from typing import Optional

STATE_FILE = "claude-self-review"

# Marks from other branches and worktrees are kept so that switching between
# them does not ask for the same review again.
HISTORY = 20

MAX_UNTRACKED = 200
MAX_UNTRACKED_BYTES = 256 * 1024

# Every ref costs a merge-base call, and the hook has one timeout for all of them.
MAX_BASE_REFS = 3

GIT_HANDS_ON = ("push", "merge")

# --abort and friends end a merge instead of making one.
MERGE_ESCAPES = ("--abort", "--continue", "--quit")

GH_PR_HANDS_ON = ("create", "merge", "ready")

# --undo puts a pull request back to draft, which withdraws work instead.
GH_ESCAPES = ("--undo",)

# Stands in for a newline, which separates commands unless it is inside quotes.
LINE_BREAK = "\0"

SEPARATORS = ("&&", "||", ";", "|", "&", "(", ")", LINE_BREAK)

# Commands that run another command: the one that matters is behind them.
WRAPPERS = ("sudo", "env", "command", "time", "nohup", "xargs", "exec")
SHELLS = ("bash", "sh", "zsh", "dash")

# Shell syntax standing between a separator and the command it introduces.
KEYWORDS = ("then", "else", "elif", "do", "done", "fi", "esac", "{", "}", "!")

ASSIGNMENT = re.compile(r"^\w+=")

HEREDOC = re.compile(r"<<-?\s*[\"']?(?P<word>\w+)[\"']?")

GIT_GLOBAL_WITH_VALUE = ("-C", "-c", "--git-dir", "--work-tree", "--namespace")

BASE_CANDIDATES = (
    "refs/remotes/origin/main",
    "refs/remotes/origin/master",
    "refs/remotes/origin/trunk",
    "refs/remotes/origin/develop",
    "refs/heads/main",
    "refs/heads/master",
    "refs/heads/trunk",
)


def git(repo: str, *args: str, keep_edges: bool = False) -> Optional[str]:
    try:
        done = subprocess.run(
            ["git", "-C", repo, *args],
            capture_output=True,
            text=True,
            errors="replace",
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError, ValueError):
        return None
    if done.returncode != 0:
        return None
    return done.stdout if keep_edges else done.stdout.strip()


def repo_root(path: str) -> str:
    """Every command runs from the top level: `ls-files` only reports below its cwd."""
    return git(path, "rev-parse", "--show-toplevel") or path


def base_refs(repo: str) -> list[str]:
    # The upstream comes first because it is the tightest base. Work that is
    # already on it passed this same gate on its way out.
    upstream = git(repo, "rev-parse", "--symbolic-full-name", "@{upstream}")
    origin_head = git(repo, "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD")
    listed = git(repo, "for-each-ref", "--format=%(refname)", *BASE_CANDIDATES) or ""
    existing = set(listed.split())
    ordered = [ref for ref in BASE_CANDIDATES if ref in existing]
    refs: list[str] = []
    for ref in [upstream, origin_head, *ordered]:
        if ref and ref not in refs:
            refs.append(ref)
    return refs[:MAX_BASE_REFS]


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
        keep_edges=True,
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
        if git(repo, "rev-parse", "--is-inside-work-tree") != "true":
            return None
        staged = git(repo, "diff", "--cached")
        if staged is None:
            return digest("git unavailable")
        return combine(staged, git(repo, "diff") or "", untracked(repo))

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


def without_heredocs(command: str) -> str:
    """A heredoc body is data: a line of documentation may well say `git push`."""
    lines = command.splitlines()
    kept: list[str] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        kept.append(line)
        index += 1
        for match in HEREDOC.finditer(line):
            while index < len(lines) and lines[index].strip() != match.group("word"):
                index += 1
            index += 1
    return "\n".join(kept)


def segments(command: str) -> list[list[str]]:
    lexer = shlex.shlex(
        without_heredocs(command).replace("\n", f" {LINE_BREAK} "),
        posix=True,
        punctuation_chars=True,
    )
    lexer.whitespace_split = True
    try:
        tokens = list(lexer)
    except ValueError:
        return []
    groups: list[list[str]] = [[]]
    for token in tokens:
        if token in SEPARATORS:
            groups.append([])
        else:
            groups[-1].append(token)
    return [group for group in groups if group]


def unwrap(tokens: list[str]) -> list[str]:
    while tokens:
        if tokens[0] in KEYWORDS or ASSIGNMENT.match(tokens[0]):
            tokens = tokens[1:]
        elif os.path.basename(tokens[0]) in WRAPPERS:
            tokens = tokens[1:]
        else:
            return tokens
    return tokens


def git_subcommand(args: list[str]) -> tuple[str, str, list[str]]:
    """The -C directory, the subcommand, and its arguments, past git's own options."""
    directory = ""
    index = 0
    while index < len(args):
        token = args[index]
        if token in GIT_GLOBAL_WITH_VALUE:
            if token == "-C" and index + 1 < len(args):
                directory = args[index + 1]
            index += 2
            continue
        if token.startswith("-"):
            index += 1
            continue
        return directory, token, args[index + 1 :]
    return directory, "", []


def hands_work_on(command: str) -> Optional[str]:
    """Directory a command would hand work out of, or None when it keeps it here."""
    directory = ""
    for tokens in map(unwrap, segments(command)):
        if not tokens:
            continue
        name = os.path.basename(tokens[0])
        if name in SHELLS:
            script = shell_script(tokens[1:])
            inner = hands_work_on(script) if script else None
            if inner is not None:
                return inner or directory
        elif name == "cd" and len(tokens) > 1:
            directory = tokens[1]
        elif name == "git":
            target, subcommand, args = git_subcommand(tokens[1:])
            if subcommand in GIT_HANDS_ON and not set(args) & set(MERGE_ESCAPES):
                return target or directory
        elif name == "gh":
            args = [token for token in tokens[1:] if not token.startswith("-")]
            escaped = set(tokens[1:]) & set(GH_ESCAPES)
            if args[:1] == ["pr"] and args[1:2] and args[1] in GH_PR_HANDS_ON:
                if not escaped:
                    return directory
    return None


def shell_script(args: list[str]) -> Optional[str]:
    """The script a `sh -c` style invocation would run."""
    for index, token in enumerate(args):
        if token.startswith("-") and "c" in token.lstrip("-"):
            return args[index + 1] if index + 1 < len(args) else None
    return None


def mark_command() -> str:
    """Spelled as the settings allowlist has it, so running it does not prompt."""
    path = os.path.abspath(__file__)
    installed = os.path.join(os.path.expanduser("~"), ".claude", "hooks")
    if os.path.dirname(path) == installed:
        return 'python3 "$HOME/.claude/hooks/self-review.py" --mark'
    return f"python3 {path} --mark"


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
    if payload.get("tool_name") != "Bash":
        return 0

    tool_input = payload.get("tool_input") or {}
    directory = hands_work_on(tool_input.get("command") or "")
    if directory is None:
        return 0

    cwd = payload.get("cwd") or os.getcwd()
    repo = repo_root(os.path.join(cwd, os.path.expanduser(directory)))
    if git(repo, "rev-parse", "--is-inside-work-tree") != "true":
        # An unexpanded ~ or $VAR names no repository; fall back to the one here
        # rather than reading a missing directory as nothing to review.
        repo = repo_root(cwd)
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
                        "Run the self-review skill on it and address what comes "
                        "back. If a review does not apply to this diff, say so in "
                        "your reply. Either way it is recorded with: "
                        f"{mark_command()}"
                    ),
                }
            }
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
