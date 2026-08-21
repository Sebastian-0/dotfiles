#!/usr/bin/env python3
"""Tests for the self-review hook: python3 -m unittest discover claude/hooks"""

import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import Optional

HOOK = Path(__file__).with_name("self-review.py")

spec = importlib.util.spec_from_file_location("self_review", HOOK)
assert spec is not None and spec.loader is not None
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def env() -> dict[str, str]:
    """Git config the user running the tests cannot leak into, e.g. commit.gpgsign."""
    return {
        **os.environ,
        "GIT_CONFIG_GLOBAL": "/nonexistent/gitconfig",
        "GIT_CONFIG_SYSTEM": "/nonexistent/gitconfig",
    }


def git(repo: Path, *args: str) -> None:
    subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        capture_output=True,
        timeout=30,
        env=env(),
    )


def make_repo(root: Path, branch: str = "main") -> Path:
    repo = root / "repo"
    repo.mkdir()
    git(repo, "init", "-b", branch)
    git(repo, "config", "user.email", "test@example.com")
    git(repo, "config", "user.name", "Test")
    (repo / "app.py").write_text("print('hello')\n", encoding="utf-8")
    git(repo, "add", "app.py")
    git(repo, "commit", "-m", "initial")
    return repo


def make_clone(root: Path, branch: str = "main") -> Path:
    """A repo with an origin, which is what gives the hook a base to diff against."""
    origin = make_repo(root, branch)
    clone = root / "clone"
    subprocess.run(
        ["git", "clone", str(origin), str(clone)],
        check=True,
        capture_output=True,
        timeout=30,
        env=env(),
    )
    git(clone, "config", "user.email", "test@example.com")
    git(clone, "config", "user.name", "Test")
    return clone


def run_hook(
    cwd: Path, command: str = "git push", tool: str = "Bash"
) -> tuple[int, str]:
    payload = json.dumps(
        {"cwd": str(cwd), "tool_name": tool, "tool_input": {"command": command}}
    )
    done = subprocess.run(
        ["python3", str(HOOK)],
        input=payload,
        capture_output=True,
        text=True,
        cwd=str(cwd),
        timeout=30,
        env=env(),
    )
    return done.returncode, done.stdout.strip()


def run_mark(cwd: Path) -> int:
    done = subprocess.run(
        ["python3", str(HOOK), "--mark"],
        capture_output=True,
        text=True,
        cwd=str(cwd),
        timeout=30,
        env=env(),
    )
    return done.returncode


def denied(stdout: str) -> Optional[str]:
    if not stdout:
        return None
    output = json.loads(stdout)["hookSpecificOutput"]
    if output["permissionDecision"] != "deny":
        return None
    return output["permissionDecisionReason"]


def write(repo: Path, name: str, text: str) -> None:
    (repo / name).write_text(text, encoding="utf-8")


class FingerprintTest(unittest.TestCase):
    def test_clean_tree_has_nothing_to_review(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root))
            self.assertIsNone(mod.fingerprint(str(clone)))

    def test_uncommitted_edit_counts(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            write(repo, "app.py", "print('bye')\n")
            self.assertIsNotNone(mod.fingerprint(str(repo)))

    def test_staged_edit_counts(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            write(repo, "app.py", "print('bye')\n")
            git(repo, "add", "app.py")
            self.assertIsNotNone(mod.fingerprint(str(repo)))

    def test_committed_branch_work_counts(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            git(repo, "checkout", "-b", "feature")
            write(repo, "app.py", "print('feature')\n")
            git(repo, "commit", "-am", "feature")
            self.assertIsNotNone(mod.fingerprint(str(repo)))

    def test_commits_made_after_a_push_count(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root))
            git(clone, "checkout", "-b", "feature")
            write(clone, "feature.py", "print('feature')\n")
            git(clone, "add", "feature.py")
            git(clone, "commit", "-m", "feature")
            run_mark(clone)
            git(clone, "push", "-u", "origin", "feature")
            self.assertIsNone(mod.fingerprint(str(clone)))

            write(clone, "feature.py", "print('more')\n")
            git(clone, "commit", "-am", "more")
            self.assertIsNotNone(mod.fingerprint(str(clone)))

    def test_new_file_counts(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            write(repo, "feature.py", "print('new')\n")
            self.assertIsNotNone(mod.fingerprint(str(repo)))

    def test_new_file_is_seen_from_a_subdirectory(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            (repo / "sub").mkdir()
            write(repo, "sub/kept.py", "print('kept')\n")
            git(repo, "add", "sub/kept.py")
            git(repo, "commit", "-m", "sub")
            write(repo, "feature.py", "print('new')\n")
            self.assertIsNotNone(mod.fingerprint(mod.repo_root(str(repo / "sub"))))

    def test_editing_a_new_file_changes_the_fingerprint(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            write(repo, "feature.py", "print('new')\n")
            first = mod.fingerprint(str(repo))
            write(repo, "feature.py", "print('newer')\n")
            self.assertNotEqual(first, mod.fingerprint(str(repo)))

    def test_editing_a_new_file_with_a_non_ascii_name(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            write(repo, "caf\u00e9.py", "print('new')\n")
            first = mod.fingerprint(str(repo))
            write(repo, "caf\u00e9.py", "print('newer')\n")
            self.assertNotEqual(first, mod.fingerprint(str(repo)))

    def test_new_file_past_the_untracked_cap_still_shows_up(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            for step in range(mod.MAX_UNTRACKED + 5):
                write(repo, f"scratch{step:04d}.txt", "noise\n")
            first = mod.fingerprint(str(repo))
            write(repo, "zz_feature.py", "print('new')\n")
            self.assertNotEqual(first, mod.fingerprint(str(repo)))

    def test_staged_work_on_an_unborn_branch_counts(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = Path(root) / "repo"
            repo.mkdir()
            git(repo, "init", "-b", "main")
            write(repo, "feature.py", "print('new')\n")
            git(repo, "add", "feature.py")
            first = mod.fingerprint(str(repo))
            self.assertIsNotNone(first)
            write(repo, "feature.py", "print('newer')\n")
            self.assertNotEqual(first, mod.fingerprint(str(repo)))

    def test_new_file_whose_name_is_not_valid_utf8(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            (repo / os.fsdecode(b"bad\xff.py")).write_bytes(b"print('new')\n")
            self.assertIsNotNone(mod.fingerprint(str(repo)))

    def test_ignored_files_are_not_changes(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root))
            write(clone, ".gitignore", "*.log\n")
            git(clone, "add", ".gitignore")
            git(clone, "commit", "-m", "ignore logs")
            self.assertEqual(run_mark(clone), 0)
            write(clone, "scratch.log", "noise\n")
            self.assertIn(mod.fingerprint(str(clone)), mod.reviewed(str(clone)))

    def test_committed_work_on_a_default_branch_named_otherwise(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root), branch="trunk")
            write(clone, "app.py", "print('feature')\n")
            git(clone, "commit", "-am", "feature")
            self.assertIsNotNone(mod.fingerprint(str(clone)))

    def test_committed_work_without_a_remote_counts(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            write(repo, "app.py", "print('feature')\n")
            git(repo, "commit", "-am", "feature")
            self.assertIsNotNone(mod.fingerprint(str(repo)))

    def test_detached_head(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            write(repo, "app.py", "print('feature')\n")
            git(repo, "commit", "-am", "feature")
            git(repo, "checkout", "--detach", "HEAD")
            write(repo, "app.py", "print('detached')\n")
            self.assertIsNotNone(mod.fingerprint(str(repo)))

    def test_different_changes_differ(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            write(repo, "app.py", "print('one')\n")
            first = mod.fingerprint(str(repo))
            write(repo, "app.py", "print('two')\n")
            self.assertNotEqual(first, mod.fingerprint(str(repo)))

    def test_no_repository(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            self.assertIsNone(mod.fingerprint(root))
            self.assertIsNone(mod.state_path(root))


class CommandTest(unittest.TestCase):
    def test_commands_that_hand_work_on(self) -> None:
        for command in (
            "git push",
            "git push -u origin feature",
            "git status && git push",
            "git merge feature",
            "gh pr create --fill",
            "gh pr merge 3",
            "gh pr ready",
            "git add -A\ngit commit -m x\ngit push -u origin feature",
            "echo hi; git push",
            "git status;git push",
            "if true; then git push; fi",
            "for r in a b; do git push $r; done",
            "FOO=1 git push",
            "sudo git push",
            "env FOO=1 git push",
            "time git push",
            "echo main | xargs git push origin",
            'bash -c "git push"',
        ):
            self.assertEqual(mod.hands_work_on(command), "", command)

    def test_commands_that_keep_work_here(self) -> None:
        for command in (
            'git commit -m "Gate the review at push and merge"',
            "git add src/merge.py",
            "git stash push",
            "git log --grep=merge",
            "git merge --abort",
            "git merge-base main HEAD",
            'grep -rn "git push" claude/',
            "gh pr view 3",
            "gh pr ready --undo",
            "git status",
            'git commit -m "one line\nanother that says git push"',
            "cat > notes.md <<'MD'\ngit push -u origin main\nMD",
        ):
            self.assertIsNone(mod.hands_work_on(command), command)

    def test_the_directory_a_command_acts_on(self) -> None:
        self.assertEqual(mod.hands_work_on("git -C /other/repo push"), "/other/repo")
        self.assertEqual(mod.hands_work_on("cd /other/repo && git push"), "/other/repo")
        self.assertEqual(mod.hands_work_on("(cd sub && git push)"), "sub")


class GateTest(unittest.TestCase):
    def test_denies_a_push_of_unreviewed_changes(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root))
            write(clone, "app.py", "print('bye')\n")
            code, stdout = run_hook(clone, "git push -u origin feature")
            self.assertEqual(code, 0)
            reason = denied(stdout)
            assert reason is not None
            self.assertIn("self-review", reason)

    def test_denies_the_first_push_of_committed_work(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root))
            git(clone, "checkout", "-b", "feature")
            write(clone, "feature.py", "print('feature')\n")
            git(clone, "add", "feature.py")
            git(clone, "commit", "-m", "feature")
            self.assertIsNotNone(
                denied(run_hook(clone, "git push -u origin feature")[1])
            )

    def test_denies_a_pull_request_and_a_merge(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root))
            write(clone, "app.py", "print('bye')\n")
            for command in (
                "gh pr create --fill",
                "gh pr merge 3",
                "git merge feature",
            ):
                self.assertIsNotNone(denied(run_hook(clone, command)[1]), command)

    def test_allows_commands_that_hand_nothing_on(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root))
            write(clone, "app.py", "print('bye')\n")
            for command in (
                "git status",
                "git commit -am wip",
                "git merge-base main HEAD",
                "git log --oneline",
            ):
                self.assertEqual(run_hook(clone, command), (0, ""), command)

    def test_ignores_other_tools(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root))
            write(clone, "app.py", "print('bye')\n")
            self.assertEqual(run_hook(clone, "git push", tool="Write"), (0, ""))

    def test_allows_a_push_with_nothing_to_review(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root))
            self.assertEqual(run_hook(clone), (0, ""))

    def test_mark_opens_the_gate_until_the_diff_changes(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root))
            write(clone, "app.py", "print('bye')\n")
            self.assertEqual(run_mark(clone), 0)
            self.assertIsNone(denied(run_hook(clone)[1]))

            write(clone, "app.py", "print('bye again')\n")
            self.assertIsNotNone(denied(run_hook(clone)[1]))

    def test_committing_reviewed_work_keeps_the_gate_open(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root))
            git(clone, "checkout", "-b", "feature")
            write(clone, "app.py", "print('feature')\n")
            self.assertEqual(run_mark(clone), 0)
            git(clone, "commit", "-am", "feature")
            self.assertIsNone(denied(run_hook(clone)[1]))

    def test_marking_from_a_subdirectory_matches_the_gate(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root))
            (clone / "sub").mkdir()
            write(clone, "app.py", "print('bye')\n")
            self.assertEqual(run_mark(clone / "sub"), 0)
            self.assertIsNone(denied(run_hook(clone)[1]))

    def test_switching_branches_keeps_both_reviews(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root))
            git(clone, "checkout", "-b", "one")
            write(clone, "app.py", "print('one')\n")
            git(clone, "commit", "-am", "one")
            self.assertEqual(run_mark(clone), 0)

            git(clone, "checkout", "-b", "two", "main")
            write(clone, "app.py", "print('two')\n")
            git(clone, "commit", "-am", "two")
            self.assertIsNotNone(denied(run_hook(clone)[1]))
            self.assertEqual(run_mark(clone), 0)

            git(clone, "checkout", "one")
            self.assertIsNone(denied(run_hook(clone)[1]))

    def test_marking_in_a_worktree_keeps_the_other_review(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root))
            write(clone, "app.py", "print('main tree')\n")
            self.assertEqual(run_mark(clone), 0)

            tree = Path(root) / "linked"
            git(clone, "worktree", "add", "-b", "linked", str(tree))
            write(tree, "app.py", "print('linked tree')\n")
            self.assertEqual(run_mark(tree), 0)

            self.assertIsNone(denied(run_hook(clone)[1]))
            self.assertIsNone(denied(run_hook(tree)[1]))

    def test_mark_keeps_only_the_recent_history(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root))
            for step in range(mod.HISTORY + 3):
                write(clone, "app.py", f"print({step})\n")
                self.assertEqual(run_mark(clone), 0)
            self.assertEqual(len(mod.reviewed(str(clone))), mod.HISTORY)

    def test_unreadable_state_file_still_denies(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root))
            write(clone, "app.py", "print('bye')\n")
            state = mod.state_path(str(clone))
            assert state is not None
            Path(state).write_bytes(b"\xff\xfe not text at all")
            self.assertIsNotNone(denied(run_hook(clone)[1]))
            self.assertEqual(run_mark(clone), 0)
            self.assertIsNone(denied(run_hook(clone)[1]))

    def test_outside_a_repository(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            self.assertEqual(run_hook(Path(root)), (0, ""))
            self.assertEqual(run_mark(Path(root)), 1)

    def test_denies_a_push_of_an_unresolvable_directory(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root))
            write(clone, "app.py", "print('bye')\n")
            self.assertIsNotNone(denied(run_hook(clone, "git -C $REPO push")[1]))

    def test_denies_a_push_of_another_repository(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            here = make_clone(Path(root))
            elsewhere = Path(root) / "elsewhere"
            elsewhere.mkdir()
            there = make_clone(elsewhere)
            write(there, "app.py", "print('unreviewed')\n")
            self.assertIsNotNone(denied(run_hook(here, f"git -C {there} push")[1]))
            self.assertIsNone(denied(run_hook(there, f"git -C {here} push")[1]))

    def test_allows_a_pushed_branch_with_nothing_new(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root))
            git(clone, "checkout", "-b", "develop")
            write(clone, "feature.py", "print('feature')\n")
            git(clone, "add", "feature.py")
            git(clone, "commit", "-m", "feature")
            self.assertEqual(run_mark(clone), 0)
            git(clone, "push", "-u", "origin", "develop")
            self.assertIsNone(denied(run_hook(clone, "git merge other")[1]))

    def test_unknown_arguments_are_refused(self) -> None:
        done = subprocess.run(
            ["python3", str(HOOK), "--marks"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertEqual(done.returncode, 2)


if __name__ == "__main__":
    unittest.main()
