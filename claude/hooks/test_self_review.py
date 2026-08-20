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


def env(root: Path) -> dict[str, str]:
    """Git config the user running the tests cannot leak into, e.g. commit.gpgsign."""
    return {
        **os.environ,
        "GIT_CONFIG_GLOBAL": str(root / "gitconfig"),
        "GIT_CONFIG_SYSTEM": str(root / "gitconfig"),
    }


def git(repo: Path, *args: str) -> None:
    subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        capture_output=True,
        timeout=30,
        env=env(repo.parent),
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
        env=env(root),
    )
    git(clone, "config", "user.email", "test@example.com")
    git(clone, "config", "user.name", "Test")
    return clone


def write(repo: Path, name: str, text: str) -> None:
    (repo / name).write_text(text, encoding="utf-8")


def run_hook(cwd: Path, stop_hook_active: bool = False) -> tuple[int, str]:
    payload = json.dumps({"cwd": str(cwd), "stop_hook_active": stop_hook_active})
    done = subprocess.run(
        ["python3", str(HOOK)],
        input=payload,
        capture_output=True,
        text=True,
        cwd=str(cwd),
        timeout=30,
        env=env(Path(cwd).parent),
    )
    return done.returncode, done.stdout.strip()


def run_mark(cwd: Path) -> int:
    done = subprocess.run(
        ["python3", str(HOOK), "--mark"],
        capture_output=True,
        text=True,
        cwd=str(cwd),
        timeout=30,
        env=env(Path(cwd).parent),
    )
    return done.returncode


def blocked(stdout: str) -> Optional[str]:
    if not stdout:
        return None
    payload = json.loads(stdout)
    return payload["reason"] if payload.get("decision") == "block" else None


class FingerprintTest(unittest.TestCase):
    def test_clean_tree_has_nothing_to_review(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            self.assertIsNone(mod.fingerprint(str(repo)))

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

    def test_new_file_counts(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            write(repo, "feature.py", "print('new')\n")
            self.assertIsNotNone(mod.fingerprint(str(repo)))

    def test_editing_a_new_file_changes_the_fingerprint(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            write(repo, "feature.py", "print('new')\n")
            first = mod.fingerprint(str(repo))
            write(repo, "feature.py", "print('newer')\n")
            self.assertNotEqual(first, mod.fingerprint(str(repo)))

    def test_ignored_files_are_not_changes(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            write(repo, ".gitignore", "*.log\n")
            git(repo, "add", ".gitignore")
            git(repo, "commit", "-m", "ignore logs")
            write(repo, "scratch.log", "noise\n")
            self.assertIsNone(mod.fingerprint(str(repo)))

    def test_committed_work_on_a_default_branch_named_otherwise(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root), branch="trunk")
            write(clone, "app.py", "print('feature')\n")
            git(clone, "commit", "-am", "feature")
            self.assertIsNotNone(mod.fingerprint(str(clone)))

    def test_committed_work_without_a_remote_counts_once_reviews_started(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            write(repo, "app.py", "print('feature')\n")
            run_mark(repo)
            git(repo, "commit", "-am", "feature")
            self.assertIsNotNone(mod.fingerprint(str(repo)))

    def test_untouched_repo_without_a_remote_is_left_alone(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            self.assertIsNone(mod.fingerprint(str(repo)))

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


class HookTest(unittest.TestCase):
    def test_silent_without_changes(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            code, stdout = run_hook(repo)
            self.assertEqual(code, 0)
            self.assertEqual(stdout, "")

    def test_blocks_on_unreviewed_changes(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            write(repo, "app.py", "print('bye')\n")
            code, stdout = run_hook(repo)
            self.assertEqual(code, 0)
            reason = blocked(stdout)
            assert reason is not None
            self.assertIn("self-review", reason)

    def test_blocks_on_a_new_file_alone(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            write(repo, "feature.py", "print('new')\n")
            self.assertIsNotNone(blocked(run_hook(repo)[1]))

    def test_mark_silences_until_the_diff_changes(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            write(repo, "app.py", "print('bye')\n")
            self.assertEqual(run_mark(repo), 0)
            self.assertIsNone(blocked(run_hook(repo)[1]))

            write(repo, "app.py", "print('bye again')\n")
            self.assertIsNotNone(blocked(run_hook(repo)[1]))

    def test_committing_reviewed_work_stays_silent(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            clone = make_clone(Path(root))
            git(clone, "checkout", "-b", "feature")
            write(clone, "app.py", "print('feature')\n")
            self.assertEqual(run_mark(clone), 0)
            git(clone, "commit", "-am", "feature")
            self.assertIsNone(blocked(run_hook(clone)[1]))

    def test_switching_branches_keeps_both_reviews(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            git(repo, "checkout", "-b", "one")
            write(repo, "app.py", "print('one')\n")
            git(repo, "commit", "-am", "one")
            self.assertEqual(run_mark(repo), 0)

            git(repo, "checkout", "-b", "two", "main")
            write(repo, "app.py", "print('two')\n")
            git(repo, "commit", "-am", "two")
            self.assertIsNotNone(blocked(run_hook(repo)[1]))
            self.assertEqual(run_mark(repo), 0)

            git(repo, "checkout", "one")
            self.assertIsNone(blocked(run_hook(repo)[1]))

    def test_marking_in_a_worktree_keeps_the_other_review(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            write(repo, "app.py", "print('main tree')\n")
            self.assertEqual(run_mark(repo), 0)

            tree = Path(root) / "linked"
            git(repo, "worktree", "add", "-b", "linked", str(tree))
            write(tree, "app.py", "print('linked tree')\n")
            self.assertEqual(run_mark(tree), 0)

            self.assertIsNone(blocked(run_hook(repo)[1]))
            self.assertIsNone(blocked(run_hook(tree)[1]))

    def test_mark_keeps_only_the_recent_history(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            for step in range(mod.HISTORY + 3):
                write(repo, "app.py", f"print({step})\n")
                self.assertEqual(run_mark(repo), 0)
            self.assertEqual(len(mod.reviewed(str(repo))), mod.HISTORY)

    def test_stop_hook_active_does_not_loop(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            write(repo, "app.py", "print('bye')\n")
            self.assertEqual(run_hook(repo, stop_hook_active=True), (0, ""))

    def test_outside_a_repository(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            self.assertEqual(run_hook(Path(root)), (0, ""))
            self.assertEqual(run_mark(Path(root)), 1)


if __name__ == "__main__":
    unittest.main()
