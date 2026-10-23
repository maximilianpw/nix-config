"""Exercise the generated jj config without contacting a network remote."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class JujutsuWorkflowTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="jj-workflow-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.remote = self.root / "remote.git"
        self.env = dict(os.environ)
        self.env.pop("JJ_AGENT", None)
        self.run_command(["git", "init", "--bare", str(self.remote)], cwd=self.root)
        self.run_command(["jj", "git", "init", "--colocate", str(self.repo)], cwd=self.root)
        self.jj("config", "set", "--repo", "git.sign-on-push", "false")
        self.jj("config", "set", "--repo", "user.name", "Fixture")
        self.jj("config", "set", "--repo", "user.email", "fixture@example.invalid")
        (self.repo / "base.txt").write_text("base\n")
        self.jj("describe", "-m", "base")
        self.jj("bookmark", "create", "main")
        self.jj("git", "remote", "add", "origin", str(self.remote))
        self.jj("git", "push", "-b", "main")

    def run_command(self, args, *, cwd=None, env=None, success=True):
        result = subprocess.run(
            args, cwd=cwd or self.repo, env=env or self.env,
            text=True, capture_output=True, check=False,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def jj(self, *args, **kwargs):
        return self.run_command(["jj", "--no-pager", *args], **kwargs)

    def revision(self, revset):
        return self.jj("log", "-r", revset, "--no-graph", "-T", "commit_id").stdout

    def feature(self):
        self.jj("new", "main", "-m", "feature")
        (self.repo / "feature.txt").write_text("feature\n")
        self.jj("bookmark", "create", "feature")
        self.jj("git", "push", "-b", "feature")
        self.jj("new", "main")

    def merge_and_delete_remote_feature(self):
        upstream = self.root / "upstream"
        self.run_command(["git", "clone", "-b", "main", str(self.remote), str(upstream)])
        self.run_command(["git", "merge", "--squash", "origin/feature"], cwd=upstream)
        self.run_command([
            "git", "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
            "-c", "commit.gpgSign=false", "commit", "-m", "squash merge",
        ], cwd=upstream)
        self.run_command(["git", "push", "origin", "main", ":feature"], cwd=upstream)
        self.jj("f")
        self.assertEqual(self.jj("file", "show", "-r", "main", "feature.txt").stdout, "feature\n")

    def test_private_commit_guard_and_agent_scope(self):
        self.jj("new", "main", "-m", "private: do not publish")
        (self.repo / "private.txt").write_text("fixture, not a secret\n")
        self.jj("bookmark", "create", "private-test")
        result = self.jj("git", "push", "-b", "private-test", "--dry-run", success=False)
        self.assertIn("since it is private", result.stderr)
        self.jj("describe", "-m", "wip: do not publish")
        result = self.jj("git", "push", "-b", "private-test", "--dry-run", success=False)
        self.assertIn("since it is private", result.stderr)
        self.jj("describe", "-m", "ready for review")
        self.jj("git", "push", "-b", "private-test", "--dry-run")

        self.assertEqual(self.jj("config", "get", "ui.editor").stdout.strip(), "nvim")
        agent_env = dict(self.env, JJ_AGENT="1")
        for key, value in {
            "ui.paginate": "never", "ui.color": "never",
            "ui.diff-formatter": ":git", "ui.conflict-marker-style": "snapshot",
        }.items():
            self.assertEqual(self.jj("config", "get", key, env=agent_env).stdout.strip(), value)
        self.jj("describe", "-m", "explicit message", env=agent_env)
        self.jj("describe", env=agent_env, success=False)
        self.jj("tidy", success=False)
        self.jj("tidy-all", success=False)

    def test_stack_check_does_not_rewrite_and_propagates_failure(self):
        self.jj("new", "main", "-m", "first layer")
        (self.repo / "feature.txt").write_text("first\n")
        self.jj("new", "-m", "second layer")
        (self.repo / "feature.txt").write_text("second\n")
        self.jj("new")
        revset = "mutable() & ::@ & ~empty()"
        before = self.revision(revset)
        marker = self.root / "checked"
        self.jj("check-stack", "sh", "-c", 'echo checked >> "$1"; echo modified > feature.txt', "sh", str(marker))
        self.assertEqual(marker.read_text().splitlines(), ["checked", "checked"])
        self.assertEqual(self.revision(revset), before)
        self.assertEqual((self.repo / "feature.txt").read_text(), "second\n")
        self.jj("check-stack", "sh", "-c", "exit 7", success=False)
        self.assertEqual(self.revision(revset), before)

    def test_tug_advances_trunk_when_it_is_the_closest_bookmark(self):
        original = self.revision("main")
        self.jj("new", "main", "-m", "unbookmarked work")
        (self.repo / "feature.txt").write_text("work\n")
        self.jj("new")
        self.jj("tug")
        self.assertEqual(self.revision("main"), self.revision("@-"))
        self.assertNotEqual(self.revision("main"), original)
        self.assertEqual(self.revision("main@origin"), original)

    def test_tug_advances_only_the_closest_bookmark_unless_named(self):
        original = self.revision("main")
        self.jj("new", "main", "-m", "feature")
        (self.repo / "feature.txt").write_text("work\n")
        self.jj("bookmark", "create", "feature")
        self.jj("new", "-m", "follow-up")
        (self.repo / "feature.txt").write_text("follow-up\n")
        self.jj("new")
        self.jj("tug")
        self.assertEqual(self.revision("feature"), self.revision("@-"))
        self.assertEqual(self.revision("main"), original)
        self.jj("tug", "main")
        self.assertEqual(self.revision("main"), self.revision("@-"))
        self.assertEqual(self.revision("main@origin"), original)

    def test_fetch_removes_unchanged_tracking_bookmark_after_squash_merge(self):
        self.feature()
        self.merge_and_delete_remote_feature()
        self.assertEqual(self.jj("bookmark", "list", "feature").stdout, "")

    def test_fetch_preserves_locally_rewritten_bookmark_as_conflict(self):
        self.feature()
        self.jj("describe", "-r", "feature", "-m", "local edit not pushed")
        local = self.revision("feature")
        self.merge_and_delete_remote_feature()
        self.assertIn("feature (conflicted)", self.jj("bookmark", "list", "feature").stdout)
        self.assertIn(local, self.revision("all()"))

    def test_fetch_keeps_untracked_local_bookmark(self):
        self.feature()
        local = self.revision("feature")
        self.jj("bookmark", "untrack", "feature", "--remote", "origin")
        self.merge_and_delete_remote_feature()
        self.assertEqual(self.revision("feature"), local)

    def test_stack_aliases_reach_packaged_cli_without_publishing(self):
        self.assertIn("submit", self.jj("stack", "--help").stdout)
        self.assertIn("--all", self.jj("sync", "--help").stdout)
        self.assertEqual(self.jj("stack", "in-use", success=False).returncode, 1)


if __name__ == "__main__":
    unittest.main()
