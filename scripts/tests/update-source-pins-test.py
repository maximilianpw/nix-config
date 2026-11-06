#!/usr/bin/env python3
"""Offline CLI tests using real source files in disposable checkouts."""

import base64
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[2]
SCRIPT = "scripts/dev/update-source-pins.py"
spec = importlib.util.spec_from_file_location("source_pins", REPO / SCRIPT)
pins = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pins)
HASH = "sha256-" + base64.b64encode(bytes.fromhex("ab" * 32)).decode()
REVISION = "b" * 40


class SourcePinsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in [SCRIPT, "flake.nix", "packages/obsidian.nix", "packages/herdr-core.nix", "users/maxpw/modules/shells.nix", "homelab/executor.nix", "homelab/media/companions.nix", "users/maxpw/agents/claude/settings.json", "users/maxpw/agents/opencode/cliproxyapi.json"]:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(REPO / name, target)
        binary = self.root / "bin"
        binary.mkdir()
        stub = binary / "stub"
        stub.write_text(f"#!{sys.executable}\n" + '''import json, os, pathlib, sys
command = [pathlib.Path(sys.argv[0]).name, *sys.argv[1:]]
if pathlib.Path.cwd() != pathlib.Path(os.environ["PIN_TEST_RESPONSES"]).parent:
    print("command ran outside the source checkout", file=sys.stderr)
    sys.exit(98)
with open(os.environ["PIN_TEST_CALLS"], "a") as output:
    output.write(json.dumps(command) + "\\n")
data = json.loads(pathlib.Path(os.environ["PIN_TEST_RESPONSES"]).read_text())
response = data.get(json.dumps(command))
if response is None:
    print("unexpected command: " + repr(command), file=sys.stderr)
    sys.exit(97)
if isinstance(response, int):
    sys.exit(response)
sys.stdout.write(response)
''')
        stub.chmod(0o755)
        for name in ("nix", "gh", "curl", "skopeo"):
            (binary / name).symlink_to(stub)
        self.responses = {}
        self.env = {**os.environ, "PATH": str(binary) + os.pathsep + os.environ["PATH"], "PIN_TEST_RESPONSES": str(self.root / "responses.json"), "PIN_TEST_CALLS": str(self.root / "calls.jsonl")}

    def respond(self, args, result):
        self.responses[json.dumps(args)] = result if isinstance(result, (str, int)) else json.dumps(result)

    def run_group(self, group, success=True):
        (self.root / "responses.json").write_text(json.dumps(self.responses))
        result = subprocess.run([sys.executable, str(self.root / SCRIPT), group], env=self.env, text=True, capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0 if success else 1, result.stdout + result.stderr)
        return result

    def read(self, filename):
        return (self.root / filename).read_text()

    def tags(self, repo, tags):
        self.respond(["gh", "api", f"repos/{repo}/tags?per_page=100&page=1"], [{"name": tag} for tag in tags])

    def fetch(self, url, result):
        self.respond(["curl", "--fail", "--silent", "--show-error", "--location", "--max-time", "60", url], result)

    def prefetch(self, url, result=None):
        self.respond(["nix", "store", "prefetch-file", "--json", url], {"hash": HASH} if result is None else result)

    def prepare_inputs(self):
        for repo, policy in pins.FLAKE_INPUTS.values():
            if policy == "commit":
                self.respond(["gh", "api", f"repos/{repo}/commits/HEAD"], {"sha": REVISION})
                self.flake_source(f"github:{repo}/{REVISION}")
            else:
                self.tags(repo, ["v9.1.1", "v9.10.0", "v10.0.0-beta.1", "not-a-version"])
                prefix = f"git+ssh://git@github.com/{repo}?ref=refs/tags/" if repo.endswith("homelab-mcp") else f"github:{repo}/"
                self.flake_source(prefix + "v9.10.0")

    def flake_source(self, url, available=True):
        source = self.root / "sources" / hashlib.sha256(url.encode()).hexdigest()
        source.mkdir(parents=True, exist_ok=True)
        if available:
            (source / "flake.nix").write_text('{ outputs = { self }: {}; }\n')
        else:
            (source / "flake.nix").unlink(missing_ok=True)
        self.respond(["nix", "flake", "prefetch", "--json", url], {"storePath": str(source)})

    def test_release_without_flake_is_not_written_to_input(self):
        self.prepare_inputs()
        path = self.root / "flake.nix"
        path.write_text(re.sub(r'github:maximilianpw/loggle/[^\"]+', "github:maximilianpw/loggle/v0.2.0", path.read_text()))
        self.tags("maximilianpw/loggle", ["v1.0.0", "v0.2.0"])
        self.flake_source("github:maximilianpw/loggle/v1.0.0", available=False)
        self.flake_source("github:maximilianpw/loggle/v0.2.0")
        result = self.run_group("flake-inputs")
        self.assertIn("loggle v1.0.0 has no flake.nix", result.stdout)
        selected = re.search(r'github:maximilianpw/loggle/[^\"]+', self.read("flake.nix"))[0]
        self.assertEqual(selected, "github:maximilianpw/loggle/v0.2.0")

    def test_no_compatible_release_preserves_pin_without_downgrading(self):
        self.prepare_inputs()
        path = self.root / "flake.nix"
        path.write_text(re.sub(r'github:maximilianpw/loggle/[^\"]+', "github:maximilianpw/loggle/v0.2.0", path.read_text()))
        self.tags("maximilianpw/loggle", ["v1.0.0", "v0.1.3"])
        self.flake_source("github:maximilianpw/loggle/v1.0.0", available=False)
        result = self.run_group("flake-inputs", success=False)
        self.assertIn("no flake-compatible stable tag at or above v0.2.0", result.stderr)
        self.assertIn('"github:maximilianpw/loggle/v0.2.0"', self.read("flake.nix"))
        self.assertIn("portfolio-tracker/v9.10.0", self.read("flake.nix"))

    def test_flake_fetch_failure_is_not_treated_as_a_missing_file(self):
        self.prepare_inputs()
        before = re.search(r'github:maximilianpw/loggle/[^\"]+', self.read("flake.nix"))[0]
        self.respond(["nix", "flake", "prefetch", "--json", "github:maximilianpw/loggle/v9.10.0"], 1)
        self.flake_source("github:maximilianpw/loggle/v9.1.1")
        result = self.run_group("flake-inputs", success=False)
        self.assertIn("Source pin update failed: loggle:", result.stderr)
        self.assertNotIn("Skipping flake release: maximilianpw/loggle", result.stdout)
        self.assertIn('"' + before + '"', self.read("flake.nix"))
        calls = (self.root / "calls.jsonl").read_text()
        self.assertNotIn("github:maximilianpw/loggle/v9.1.1", calls)

    def test_commit_without_flake_preserves_pin(self):
        self.prepare_inputs()
        before = re.search(r'github:maximilianpw/fleet/[^\"]+', self.read("flake.nix"))[0]
        self.flake_source(f"github:maximilianpw/fleet/{REVISION}", available=False)
        result = self.run_group("flake-inputs", success=False)
        self.assertIn("upstream commit for maximilianpw/fleet has no flake.nix", result.stderr)
        self.assertIn('"' + before + '"', self.read("flake.nix"))

    def test_flake_policies_and_branch_preservation(self):
        self.prepare_inputs()
        original = self.read("flake.nix")
        self.run_group("flake-inputs")
        updated = self.read("flake.nix")
        for repo, policy in pins.FLAKE_INPUTS.values():
            revision = REVISION if policy == "commit" else "v9.10.0"
            self.assertIn(repo + ("?ref=refs/tags/" if repo.endswith("homelab-mcp") else "/") + revision, updated)
        for line in original.splitlines():
            if "nixos-26.05" in line or "release-26.05" in line:
                self.assertIn(line, updated)
        self.run_group("flake-inputs")
        self.assertEqual(updated, self.read("flake.nix"))

    def test_input_failure_keeps_other_updates_and_exits_nonzero(self):
        self.prepare_inputs()
        self.respond(["gh", "api", "repos/maximilianpw/fleet/commits/HEAD"], {"sha": 'invalid"; injected = true;'})
        before = next(line for line in self.read("flake.nix").splitlines() if "github:maximilianpw/fleet/" in line)
        result = self.run_group("flake-inputs", success=False)
        self.assertIn(before, self.read("flake.nix"))
        self.assertIn("portfolio-tracker/v9.10.0", self.read("flake.nix"))
        self.assertIn("fleet", result.stderr)

    def prepare_containers(self, bad_platform=None):
        images = {}
        repository = pins.CONTAINERS["executor"][2]
        self.respond(["skopeo", "list-tags", f"docker://{repository}"], {"Tags": ["latest", "1.99.0", "2.0.0-beta.9", "2.0.0-beta.10", "2.0.0-beta.100-amd64", "2.1.0", "2.1.0-beta.9", "3.0.0"]})
        for name, (_, _, repository, tag) in pins.CONTAINERS.items():
            raw = json.dumps({"schemaVersion": 2, "manifests": [], "fixture": name})
            digest = "sha256:" + hashlib.sha256(raw.encode()).hexdigest()
            images[name] = repository + "@" + digest
            self.respond(["skopeo", "inspect", "--raw", f"docker://{repository}:{tag or '2.1.0'}"], raw)
            self.respond(["skopeo", "inspect", "--override-os", "linux", "--override-arch", "amd64", "docker://" + images[name]], {"Os": "linux", "Architecture": "arm64" if name == bad_platform else "amd64"})
        return images

    def test_containers_keep_immutable_index_digest_and_executor_channel(self):
        images = self.prepare_containers()
        self.run_group("containers")
        for name, image in images.items():
            self.assertIn(image, self.read(pins.CONTAINERS[name][0]))
        self.assertNotIn(":latest\"", self.read("homelab/media/companions.nix"))

    def test_container_platform_failure_preserves_pin_and_attempts_the_rest(self):
        images = self.prepare_containers(bad_platform="executor")
        original = self.read("homelab/executor.nix")
        self.run_group("containers", success=False)
        self.assertEqual(original, self.read("homelab/executor.nix"))
        self.assertIn(images["kometa"], self.read("homelab/media/companions.nix"))

    def test_fish_revisions_and_hashes_move_together(self):
        for repository in pins.FISH_PLUGINS.values():
            self.respond(["nix", "flake", "prefetch", "--json", "github:" + repository], {"locked": {"rev": REVISION}, "hash": HASH})
        self.run_group("fish-plugins")
        updated = self.read("users/maxpw/modules/shells.nix")
        self.assertEqual(updated.count(REVISION), 2)
        self.assertEqual(updated.count(HASH), 2)

    def test_agent_plugins_follow_locked_cli_without_reformatting_settings(self):
        self.respond(["nix", "eval", "--raw", ".#packages.x86_64-linux.plannotator.version"], "9.0.0")
        filenames = ["users/maxpw/agents/claude/settings.json", "users/maxpw/agents/opencode/cliproxyapi.json"]
        before = [self.read(filename) for filename in filenames]
        self.run_group("agent-plugins")
        for filename, original in zip(filenames, before):
            updated = self.read(filename)
            self.assertEqual(len(updated.splitlines()), len(original.splitlines()))
            self.assertEqual(sum(a != b for a, b in zip(original.splitlines(), updated.splitlines())), 1)
        claude = json.loads(self.read(filenames[0]))
        opencode = json.loads(self.read(filenames[1]))
        self.assertEqual(claude["extraKnownMarketplaces"]["plannotator"]["source"]["ref"], "v9.0.0")
        self.assertIn({"package": "@plannotator/opencode@9.0.0"}, opencode["plugins"])

    def test_agent_plugin_evaluation_failure_changes_neither_file(self):
        self.respond(["nix", "eval", "--raw", ".#packages.x86_64-linux.plannotator.version"], 1)
        filenames = ["users/maxpw/agents/claude/settings.json", "users/maxpw/agents/opencode/cliproxyapi.json"]
        before = [self.read(filename) for filename in filenames]
        self.run_group("agent-plugins", success=False)
        self.assertEqual(before, [self.read(filename) for filename in filenames])

    def prepare_obsidian(self, tag="v9.0.0"):
        self.tags("obsidianmd/obsidian-releases", [tag])
        for extension in ("AppImage", "dmg"):
            self.prefetch(f"https://github.com/obsidianmd/obsidian-releases/releases/download/{tag}/Obsidian-{tag.removeprefix('v')}.{extension}")

    def test_obsidian_updates_both_platforms_and_repairs_same_version_hashes(self):
        current = re.search(r'  version = "([^"]+)";', self.read("packages/obsidian.nix"))[1]
        self.prepare_obsidian("v" + current)
        self.run_group("obsidian")
        self.assertEqual(self.read("packages/obsidian.nix").count(HASH), 2)
        self.prepare_obsidian()
        self.run_group("obsidian")
        self.assertIn('version = "9.0.0"', self.read("packages/obsidian.nix"))

    def test_obsidian_second_download_failure_is_atomic(self):
        self.prepare_obsidian()
        self.prefetch("https://github.com/obsidianmd/obsidian-releases/releases/download/v9.0.0/Obsidian-9.0.0.dmg", 1)
        original = self.read("packages/obsidian.nix")
        self.run_group("obsidian", success=False)
        self.assertEqual(original, self.read("packages/obsidian.nix"))

    def test_obsidian_downgrade_is_rejected(self):
        self.prepare_obsidian("v0.0.1")
        original = self.read("packages/obsidian.nix")
        self.assertIn("refusing downgrade", self.run_group("obsidian", success=False).stderr)
        self.assertEqual(original, self.read("packages/obsidian.nix"))

    def prepare_herdr(self):
        targets = {}
        for target in ("macos-aarch64", "macos-x86_64", "linux-aarch64", "linux-x86_64"):
            url = f"https://releases.herdr.dev/core/9.0.0/herdr-core-{target}.tar.gz"
            targets[target] = {"url": url, "sha256": "ab" * 32}
            self.prefetch(url)
        self.fetch("https://releases.herdr.dev/core/latest.json", {"version": "9.0.0", "targets": targets})

    def test_herdr_refreshes_all_artifacts_and_verifies_checksums(self):
        self.prepare_herdr()
        self.run_group("herdr-core")
        updated = self.read("packages/herdr-core.nix")
        self.assertEqual(updated.count(HASH), 4)
        self.prefetch("https://releases.herdr.dev/core/9.0.0/herdr-core-linux-x86_64.tar.gz", {"hash": "sha256-" + base64.b64encode(bytes(32)).decode()})
        self.assertIn("checksum mismatch", self.run_group("herdr-core", success=False).stderr)
        self.assertEqual(updated, self.read("packages/herdr-core.nix"))

    def test_plex_updates_both_architectures_without_touching_cloudflared(self):
        version = "9.0.0.12345-abcdef"
        artifacts = []
        for arch in ("arm64", "amd64"):
            url = f"https://downloads.plex.tv/plex-media-server-new/{version}/debian/plexmediaserver_{version}_{arch}.deb"
            artifacts.append({"url": url})
            self.prefetch(url)
        self.fetch("https://plex.tv/api/downloads/5.json", {"computer": {"Linux": {"version": version, "releases": artifacts}}})
        original = self.read("flake.nix")
        self.run_group("plex")
        updated = self.read("flake.nix")
        self.assertIn(version, updated)
        self.assertEqual(updated.count(HASH), 2)
        self.assertEqual(original.split("plexRaw =")[0], updated.split("plexRaw =")[0])

    def test_layout_drift_fails_without_partial_write(self):
        self.prepare_obsidian()
        path = self.root / "packages/obsidian.nix"
        path.write_text(path.read_text().replace("hash =", "sha256 ="))
        original = path.read_text()
        self.assertIn("expected one source field", self.run_group("obsidian", success=False).stderr)
        self.assertEqual(original, path.read_text())


class UpdateInventoryTest(unittest.TestCase):
    def test_every_explicit_flake_pin_has_an_update_policy(self):
        text = (REPO / "flake.nix").read_text()
        repos = set(re.findall(r'github:([^/" ]+/[^/" ]+)/(?:[0-9a-f]{40}|v\d+\.\d+\.\d+)"', text))
        repos.update(re.findall(r'git\+ssh://git@github.com/([^?]+)\?ref=refs/tags/v[^"]+', text))
        self.assertEqual(repos, {repo for repo, _ in pins.FLAKE_INPUTS.values()})

    def test_every_container_digest_has_an_update_policy(self):
        repositories = set()
        for directory in ("homelab", "modules", "machines", "users"):
            for path in (REPO / directory).rglob("*.nix"):
                repositories.update(re.findall(r'"([^"\s]+)@sha256:[0-9a-f]{64}"', path.read_text()))
        self.assertEqual(repositories, {repository for _, _, repository, _ in pins.CONTAINERS.values()})

    def test_custom_package_inventory_includes_every_literal_package_version(self):
        packages = set((REPO / "scripts/ci/update-packages-list.txt").read_text().splitlines())
        for path in (REPO / "packages").glob("*.nix"):
            if re.search(r'\bversion = "', path.read_text()):
                self.assertIn(path.stem, packages)
        self.assertTrue({"cloudflared", "plex"}.issubset(packages))


if __name__ == "__main__":
    unittest.main()
