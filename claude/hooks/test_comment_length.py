#!/usr/bin/env python3
"""Tests for the comment-length hook: python3 -m unittest discover claude/hooks"""

import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import Optional

HOOK = Path(__file__).with_name("comment-length.py")

spec = importlib.util.spec_from_file_location("comment_length", HOOK)
assert spec is not None and spec.loader is not None
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

PAD = ("pad", "pad", "pad", "pad")


def src(*lines: str) -> str:
    return "\n".join(lines) + "\n"


def after_header(*lines: str) -> str:
    """Source whose first given line lands on line 5, past the header exemption."""
    return src(*PAD, *lines)


def scan(source: str, name: str = "x.sh") -> list[tuple[int, int]]:
    syntax = mod.syntax_for(name)
    assert syntax is not None, name
    lines = source.splitlines()
    return mod.long_runs(mod.comment_map(lines, syntax), len(lines), None)


def run_hook(path: str, cwd: Optional[str] = None) -> tuple[int, str]:
    payload = json.dumps({"tool_name": "Edit", "tool_input": {"file_path": path}})
    done = subprocess.run(
        ["python3", str(HOOK)],
        input=payload,
        capture_output=True,
        text=True,
        cwd=cwd,
        timeout=30,
    )
    return done.returncode, done.stdout.strip()


def context_of(stdout: str) -> str:
    return json.loads(stdout)["hookSpecificOutput"]["additionalContext"]


def git(repo: Path, *args: str) -> None:
    subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        capture_output=True,
        timeout=30,
    )


def make_repo(root: Path) -> Path:
    root.mkdir(parents=True, exist_ok=True)
    git(root, "init", "-q", ".")
    git(root, "config", "user.email", "test@example.com")
    git(root, "config", "user.name", "test")
    return root


class Threshold(unittest.TestCase):
    def test_three_prose_lines_flagged(self) -> None:
        source = after_header("# one", "# two", "# three", "code")
        self.assertEqual(scan(source), [(5, 3)])

    def test_two_prose_lines_allowed(self) -> None:
        source = after_header("# one", "# two", "code")
        self.assertEqual(scan(source), [])

    def test_max_prose_is_the_boundary(self) -> None:
        allowed = after_header(*(f"# {n}" for n in range(mod.MAX_PROSE)), "code")
        flagged = after_header(*(f"# {n}" for n in range(mod.MAX_PROSE + 1)), "code")
        self.assertEqual(scan(allowed), [])
        self.assertEqual(scan(flagged), [(5, mod.MAX_PROSE + 1)])

    def test_marker_only_lines_are_not_prose(self) -> None:
        source = after_header("# one", "#", "#", "# two", "code")
        self.assertEqual(scan(source), [])

    def test_separate_short_runs_stay_separate(self) -> None:
        source = after_header("# one", "# two", "code", "# three", "# four", "code")
        self.assertEqual(scan(source), [])

    def test_trailing_comments_are_not_a_block(self) -> None:
        source = after_header("code # one", "code # two", "code # three")
        self.assertEqual(scan(source), [])


class HeaderExemption(unittest.TestCase):
    def test_file_header_exempt(self) -> None:
        source = src("# one", "# two", "# three", "# four", "code")
        self.assertEqual(scan(source), [])

    def test_block_starting_on_last_exempt_line(self) -> None:
        source = src(*PAD[: mod.HEADER_LINES - 1], "# one", "# two", "# three", "code")
        self.assertEqual(scan(source), [])

    def test_block_starting_just_past_the_header(self) -> None:
        source = src(*PAD, "# one", "# two", "# three", "code")
        self.assertEqual(scan(source), [(mod.HEADER_LINES + 1, 3)])


class BlockComments(unittest.TestCase):
    def test_javadoc_counts_prose_not_wrapper(self) -> None:
        source = after_header("/**", " * one", " * two", " * three", " */", "code")
        self.assertEqual(scan(source, "x.cpp"), [(5, 3)])

    def test_javadoc_with_one_prose_line_allowed(self) -> None:
        source = after_header("/**", " * only one", " */", "code")
        self.assertEqual(scan(source, "x.cpp"), [])

    def test_block_without_leading_asterisks(self) -> None:
        source = after_header("/* one", "   two", "   three */", "code")
        self.assertEqual(scan(source, "x.cuh"), [(5, 3)])

    def test_single_line_block_does_not_open_a_block(self) -> None:
        source = after_header("/* one */", "code", "/* two */", "code", "/* three */")
        self.assertEqual(scan(source, "x.c"), [])

    def test_consecutive_single_line_blocks_are_one_run(self) -> None:
        source = after_header("/* one */", "/* two */", "/* three */", "code")
        self.assertEqual(scan(source, "x.c"), [(5, 3)])

    def test_code_before_opener_is_not_counted(self) -> None:
        """Known limit: prose sharing a line with code is not counted."""
        source = after_header("code; /* one", "   two", "   three */", "code")
        self.assertEqual(scan(source, "x.c"), [])

    def test_code_after_closer_ends_the_run(self) -> None:
        source = after_header("/* one", "   two */ code", "# three")
        self.assertEqual(scan(source, "x.c"), [])

    def test_lua_block_not_shadowed_by_line_prefix(self) -> None:
        source = after_header("--[[ one", "     two", "     three ]]", "code")
        self.assertEqual(scan(source, "x.lua"), [(5, 3)])

    def test_lua_line_comments(self) -> None:
        source = after_header("-- one", "-- two", "-- three", "code")
        self.assertEqual(scan(source, "x.lua"), [(5, 3)])

    def test_haskell_block(self) -> None:
        source = after_header("{- one", "   two", "   three -}", "code")
        self.assertEqual(scan(source, "x.hs"), [(5, 3)])

    def test_powershell_block(self) -> None:
        source = after_header("<# one", "   two", "   three #>", "code")
        self.assertEqual(scan(source, "x.ps1"), [(5, 3)])

    def test_ruby_block(self) -> None:
        source = after_header("=begin", "one", "two", "three", "=end", "code")
        self.assertEqual(scan(source, "x.rb"), [(5, 3)])

    def test_vim_line_comments(self) -> None:
        source = after_header('" one', '" two', '" three', "code")
        self.assertEqual(scan(source, "x.vim"), [(5, 3)])

    def test_unterminated_block_runs_to_end_of_file(self) -> None:
        source = after_header("/* one", "   two", "   three")
        self.assertEqual(scan(source, "x.cpp"), [(5, 3)])


class SyntaxSelection(unittest.TestCase):
    SLASH_EXTS = (
        "x.cuh x.cu x.cjs x.mjs x.js x.ts x.mts x.cts x.tsx x.jsx x.cpp x.cxx "
        "x.hxx x.hpp x.metal x.proto x.rs x.go x.zig x.kt x.swift x.cs"
    )
    HASH_EXTS = "x.sh x.bash x.py x.pyi x.bzl x.bazel x.yaml x.yml x.toml x.tf x.cmake"
    HASH_NAMES = "BUILD BUILD.bazel WORKSPACE MODULE.bazel Makefile justfile Dockerfile CMakeLists.txt"
    UNKNOWN = "x.md x.txt x.json x.html x.rst x"

    def test_slash_extensions(self) -> None:
        for name in self.SLASH_EXTS.split():
            with self.subTest(name=name):
                syntax = mod.syntax_for(name)
                assert syntax is not None
                self.assertIn("//", syntax.line)
                self.assertIn(("/*", "*/"), syntax.block)

    def test_hash_extensions(self) -> None:
        for name in self.HASH_EXTS.split():
            with self.subTest(name=name):
                syntax = mod.syntax_for(name)
                assert syntax is not None
                self.assertEqual(("#",), syntax.line)

    def test_extensionless_names(self) -> None:
        for name in self.HASH_NAMES.split():
            with self.subTest(name=name):
                self.assertEqual(mod.HASH, mod.syntax_for(name))

    def test_full_path_resolves_by_basename(self) -> None:
        self.assertEqual(mod.HASH, mod.syntax_for("/a/b/BUILD"))
        self.assertIsNotNone(mod.syntax_for("/a/b/x.CPP"))

    def test_unknown_types(self) -> None:
        for name in self.UNKNOWN.split():
            with self.subTest(name=name):
                self.assertIsNone(mod.syntax_for(name))

    def test_slash_is_not_a_comment_in_hash_languages(self) -> None:
        source = after_header("// one", "// two", "// three", "code")
        self.assertEqual(scan(source, "x.bzl"), [])

    def test_hash_is_not_a_comment_in_slash_languages(self) -> None:
        source = after_header("#include <a>", "#include <b>", "#include <c>")
        self.assertEqual(scan(source, "x.cpp"), [])


class HookProtocol(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)

    def write(self, name: str, source: str) -> str:
        path = self.dir / name
        path.write_text(source)
        return str(path)

    def test_violation_reports_json_context(self) -> None:
        path = self.write("bad.sh", after_header("# one", "# two", "# three", "code"))
        code, out = run_hook(path)
        self.assertEqual(0, code)
        payload = json.loads(out)
        self.assertEqual("PostToolUse", payload["hookSpecificOutput"]["hookEventName"])
        context = payload["hookSpecificOutput"]["additionalContext"]
        self.assertIn(path, context)
        self.assertIn("line 5", context)

    def test_compliant_file_is_silent(self) -> None:
        path = self.write("ok.sh", after_header("# one", "# two", "code"))
        self.assertEqual((0, ""), run_hook(path))

    def test_unknown_filetype_is_silent(self) -> None:
        path = self.write("notes.md", after_header("# one", "# two", "# three"))
        self.assertEqual((0, ""), run_hook(path))

    def test_missing_file_is_silent(self) -> None:
        self.assertEqual((0, ""), run_hook(str(self.dir / "absent.sh")))

    def test_malformed_stdin_is_silent(self) -> None:
        done = subprocess.run(
            ["python3", str(HOOK)],
            input="not json",
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertEqual(0, done.returncode)
        self.assertEqual("", done.stdout.strip())

    def test_payload_without_file_path_is_silent(self) -> None:
        done = subprocess.run(
            ["python3", str(HOOK)],
            input=json.dumps({"tool_name": "Bash", "tool_input": {"command": "ls"}}),
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertEqual(0, done.returncode)
        self.assertEqual("", done.stdout.strip())

    def test_never_blocks_on_a_violation(self) -> None:
        path = self.write("bad.py", after_header("# one", "# two", "# three", "code"))
        code, out = run_hook(path)
        self.assertEqual(0, code)
        self.assertEqual({"hookSpecificOutput"}, set(json.loads(out)))


class GitAwareness(unittest.TestCase):
    LEGACY = after_header("# one", "# two", "# three", "VALUE=1", "", 'echo "$VALUE"')

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = make_repo(Path(self.tmp.name) / "repo")
        self.other = make_repo(Path(self.tmp.name) / "other")
        self.file = self.repo / "legacy.sh"
        self.addCleanup(self.tmp.cleanup)

    def commit_legacy(self) -> None:
        self.file.write_text(self.LEGACY)
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-qm", "seed")

    def test_untracked_file_counts_every_line(self) -> None:
        self.file.write_text(self.LEGACY)
        code, out = run_hook(str(self.file))
        self.assertEqual(0, code)
        self.assertIn("line 5", context_of(out))

    def test_preexisting_block_is_not_reported(self) -> None:
        self.commit_legacy()
        self.file.write_text(self.LEGACY.replace("VALUE=1", "VALUE=2"))
        self.assertEqual((0, ""), run_hook(str(self.file)))

    def test_newly_added_block_is_reported(self) -> None:
        self.commit_legacy()
        self.file.write_text(
            self.LEGACY.replace(
                'echo "$VALUE"',
                src("# new one", "# new two", "# new three") + 'echo "$VALUE"',
            )
        )
        code, out = run_hook(str(self.file))
        self.assertEqual(0, code)
        context = context_of(out)
        self.assertIn("line 10", context)
        self.assertNotIn("line 5", context)

    def test_unrelated_cwd_does_not_defeat_the_diff(self) -> None:
        self.commit_legacy()
        self.file.write_text(self.LEGACY.replace("VALUE=1", "VALUE=2"))
        for cwd in (str(self.other), os.sep):
            with self.subTest(cwd=cwd):
                self.assertEqual((0, ""), run_hook(str(self.file), cwd=cwd))

    def test_file_outside_any_repo_counts_every_line(self) -> None:
        loose = Path(self.tmp.name) / "loose.sh"
        loose.write_text(self.LEGACY)
        code, out = run_hook(str(loose))
        self.assertEqual(0, code)
        self.assertIn("line 5", context_of(out))

    def test_repo_without_commits_counts_every_line(self) -> None:
        self.file.write_text(self.LEGACY)
        git(self.repo, "add", "-A")
        code, out = run_hook(str(self.file))
        self.assertEqual(0, code)
        self.assertIn("line 5", context_of(out))


if __name__ == "__main__":
    unittest.main()
