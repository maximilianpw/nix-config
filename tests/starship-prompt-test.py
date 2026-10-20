"""Run with python3 tests/starship-prompt-test.py; requires jj, git and starship."""

import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


CONFIG = Path(__file__).resolve().parents[1] / "users/maxpw/hjem/files/.config/starship.toml"
ANSI = re.compile(r"\x1b\[[0-9;]*m")


class StarshipPromptTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="starship-prompt-test-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.repo = self.root / "repo"
        config = self.root / "jj.toml"
        config.write_text(
            '[user]\nname = "Prompt Test"\nemail = "test@example.invalid"\n'
            '[signing]\nbehavior = "drop"\n'
        )
        self.env = {
            key: value for key, value in os.environ.items()
            if not key.startswith(("JJ_", "GIT_", "SSH_", "STARSHIP_"))
        }
        self.env.update(
            JJ_CONFIG=str(config),
            STARSHIP_CONFIG=str(CONFIG),
            STARSHIP_SHELL="sh",
            GIT_CONFIG_GLOBAL=os.devnull,
            GIT_CONFIG_NOSYSTEM="1",
        )
        self.run_command("jj", "git", "init", str(self.repo), cwd=self.root)

    def run_command(self, *args, cwd=None):
        result = subprocess.run(
            args, cwd=cwd or self.repo, env=self.env,
            text=True, capture_output=True, timeout=15,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("[WARN]", result.stderr)
        self.assertNotIn("[ERROR]", result.stderr)
        return result.stdout

    def module(self, name, cwd=None):
        return ANSI.sub("", self.run_command("starship", "module", name, cwd=cwd))

    def test_nearest_bookmark_and_current_bookmark(self):
        self.run_command("jj", "bookmark", "create", "older")
        self.run_command("jj", "new")
        self.run_command("jj", "bookmark", "create", "feature")
        self.run_command("jj", "new")
        self.run_command("jj", "new")
        output = self.module("custom.jj")
        self.assertIn("↑feature", output)
        self.assertNotIn("older", output)
        nested = self.repo / "nested"
        nested.mkdir()
        self.assertEqual(self.module("custom.jj", nested), output)
        self.run_command("jj", "bookmark", "create", "current")
        output = self.module("custom.jj")
        self.assertIn("current", output)
        self.assertNotIn("↑", output)
        self.assertNotIn("feature", output)

    def test_merge_preserves_both_bookmarked_ancestors(self):
        self.run_command("jj", "bookmark", "create", "base")
        self.run_command("jj", "new")
        self.run_command("jj", "bookmark", "create", "left")
        self.run_command("jj", "new", "base")
        self.run_command("jj", "bookmark", "create", "right")
        self.run_command("jj", "new", "left", "right")
        output = self.module("custom.jj")
        self.assertIn("↑left", output)
        self.assertIn("↑right", output)
        self.assertNotIn("base", output)

    def test_undescribed_only_for_nonempty_changes_and_no_prompt_snapshot(self):
        output = self.module("custom.jj_status")
        self.assertIn("empty", output)
        self.assertNotIn("undescribed", output)
        self.assertNotIn("↑", output)
        (self.repo / "file").write_text("content\n")
        before = self.run_command("jj", "op", "log", "--ignore-working-copy", "--no-graph", "-T", "id")
        self.assertEqual(self.module("custom.jj_status"), output)
        after = self.run_command("jj", "op", "log", "--ignore-working-copy", "--no-graph", "-T", "id")
        self.assertEqual(before, after)
        self.run_command("jj", "status")
        self.assertIn("undescribed", self.module("custom.jj_status"))
        self.run_command("jj", "describe", "-m", "Named change")
        self.assertEqual(self.module("custom.jj_status"), "")

    def test_git_fallback_and_full_prompt(self):
        self.assertEqual(self.module("custom.git"), "")
        self.assertEqual(self.module("custom.jj", self.root), "")
        self.assertEqual(self.module("custom.git", self.root), "")
        plain = self.root / "git"
        plain.mkdir()
        self.run_command("git", "init", "-b", "feature-git", cwd=plain)
        (plain / "file").write_text("untracked\n")
        self.assertEqual(self.module("custom.jj", plain), "")
        self.assertEqual(
            self.module("custom.git", plain),
            self.module("git_branch", plain) + self.module("git_status", plain),
        )
        self.assertIn("feature-git", self.module("custom.git", plain))
        self.assertIn("?1", self.module("custom.git", plain))
        self.run_command("jj", "bookmark", "create", "feature")
        self.run_command("jj", "new")
        (self.repo / "file").write_text("content\n")
        self.run_command("jj", "status")
        prompt = self.run_command("starship", "prompt")
        self.assertIn("↑feature", prompt)
        self.assertIn("undescribed", prompt)
        self.assertNotIn("HEAD", prompt)

    def test_mocha_colours_and_separators(self):
        identity = self.run_command("starship", "module", "custom.jj")
        status = self.run_command("starship", "module", "custom.jj_status")
        self.assertTrue(ANSI.sub("", identity).startswith(" "))
        self.assertEqual(ANSI.sub("", status), " · empty")
        for colour in ("38;2;203;166;247", "38;2;137;180;250"):
            self.assertIn(colour, identity)
        self.assertIn("38;2;250;179;135", status)
        self.assertEqual(self.module("custom.jj_status", self.root), "")


if __name__ == "__main__":
    unittest.main()
