#!/usr/bin/env python3
"""Tests for the self-review hook: python3 -m unittest discover claude/hooks"""

import importlib.util
import json
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


def git(repo: Path, *args: str) -> None:
    subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        capture_output=True,
        timeout=30,
    )


def make_repo(root: Path) -> Path:
    repo = root / "repo"
    repo.mkdir()
    git(repo, "init", "-b", "main")
    git(repo, "config", "user.email", "test@example.com")
    git(repo, "config", "user.name", "Test")
    (repo / "app.py").write_text("print('hello')\n", encoding="utf-8")
    git(repo, "add", "app.py")
    git(repo, "commit", "-m", "initial")
    return repo


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
    )
    return done.returncode, done.stdout.strip()


def run_mark(cwd: Path) -> int:
    done = subprocess.run(
        ["python3", str(HOOK), "--mark"],
        capture_output=True,
        text=True,
        cwd=str(cwd),
        timeout=30,
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

    def test_committed_branch_work_counts(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            git(repo, "checkout", "-b", "feature")
            write(repo, "app.py", "print('feature')\n")
            git(repo, "commit", "-am", "feature")
            self.assertIsNotNone(mod.fingerprint(str(repo)))

    def test_untracked_files_are_ignored(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            repo = make_repo(Path(root))
            write(repo, "scratch.log", "noise\n")
            self.assertIsNone(mod.fingerprint(str(repo)))

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
            repo = make_repo(Path(root))
            git(repo, "checkout", "-b", "feature")
            write(repo, "app.py", "print('feature')\n")
            self.assertEqual(run_mark(repo), 0)
            git(repo, "commit", "-am", "feature")
            self.assertIsNone(blocked(run_hook(repo)[1]))

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
