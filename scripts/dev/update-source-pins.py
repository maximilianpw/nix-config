#!/usr/bin/env python3
"""Refresh repository source pins without activating packages or containers."""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
# Commit-pinned projects track their default branch; release pins stay on stable tags.
FLAKE_INPUTS = {
    "jj-stack": ("bos/jj-stack", "commit"),
    "fleet": ("maximilianpw/fleet", "commit"),
    "loggle": ("maximilianpw/loggle", "release"),
    "herdr-jj": ("maximilianpw/herdr-jj", "release"),
    "homelab-mcp": ("maximilianpw/homelab-mcp", "release"),
    "portfolio-tracker": ("maximilianpw/portfolio-tracker", "release"),
}
CONTAINERS = {
    # Executor's latest tag is still v1. Stay on the v2 release/beta line.
    "executor": ("homelab/executor.nix", "image", "ghcr.io/usefulsoftwareco/executor-selfhost", None),
    "maintainerr": ("homelab/media/companions.nix", "maintainerrImage", "ghcr.io/maintainerr/maintainerr", "latest"),
    "tdarr": ("homelab/media/companions.nix", "tdarrImage", "ghcr.io/haveagitgat/tdarr", "latest"),
    "kometa": ("homelab/media/companions.nix", "kometaImage", "docker.io/kometateam/kometa", "latest"),
}
FISH_PLUGINS = {"fish-fzf": "jethrokuan/fzf", "fish-foreign-env": "oh-my-fish/plugin-foreign-env"}
STABLE_VERSION = re.compile(r"v?(\d+(?:\.\d+){2,3})")
SRI = re.compile(r"sha256-[A-Za-z0-9+/]{43}=")


def command(*args, timeout=300):
    return subprocess.run(args, cwd=ROOT, check=True, stdout=subprocess.PIPE, timeout=timeout).stdout


def github(endpoint):
    return json.loads(command("gh", "api", endpoint, timeout=60))


def fetch_json(url):
    return json.loads(command("curl", "--fail", "--silent", "--show-error", "--location", "--max-time", "60", url, timeout=70))


def require_match(pattern, value, label):
    if not isinstance(value, str) or re.fullmatch(pattern, value) is None:
        raise ValueError(f"invalid {label}")
    return value


def replace_once(text, pattern, replacement):
    updated, count = re.subn(pattern, replacement, text, flags=re.MULTILINE)
    if count != 1:
        raise ValueError(f"expected one source field, found {count}; check the pin's file layout")
    return updated


def save(path, original, updated):
    if path.read_text() != original:
        raise ValueError(f"{path.relative_to(ROOT)} changed during discovery; retry")
    if original == updated:
        return
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as output:
            temporary = Path(output.name)
            output.write(updated)
        temporary.chmod(path.stat().st_mode & 0o777)
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def stable_version(value):
    match = STABLE_VERSION.fullmatch(value)
    if match is None:
        raise ValueError("invalid stable version")
    return tuple(map(int, match[1].split(".")))


def stable_tags(repo):
    tags = []
    for page in range(1, 11):
        batch = github(f"repos/{repo}/tags?per_page=100&page={page}")
        if not isinstance(batch, list):
            raise ValueError("expected GitHub tags")
        tags.extend(tag["name"] for tag in batch if STABLE_VERSION.fullmatch(tag["name"]))
        if len(batch) < 100:
            break
    if not tags:
        raise ValueError(f"no stable tags found for {repo}")
    return sorted(set(tags), key=stable_version, reverse=True)


def has_flake_file(url):
    # Inspect Nix's fetched tree, not GitHub's contents API: archives can omit
    # files that are present in Git, and a fetch/auth failure is not absence.
    source = json.loads(command("nix", "flake", "prefetch", "--json", url))
    path = Path(source["storePath"])
    if not path.is_absolute():
        raise ValueError("flake prefetch returned a non-absolute store path")
    return (path / "flake.nix").is_file()


def latest_flake_tag(repo, prefix, current):
    for tag in stable_tags(repo):
        if stable_version(tag) < stable_version(current):
            break
        if has_flake_file(prefix + tag):
            return tag
        print(f"Skipping flake release: {repo} {tag} has no flake.nix in its fetched source")
    raise ValueError(f"no flake-compatible stable tag at or above {current} for {repo}; keeping the current pin")


def update_flake_input(name):
    repo, policy = FLAKE_INPUTS[name]
    path = ROOT / "flake.nix"
    original = path.read_text()
    pattern = rf'((?:\b{re.escape(name)}\.url\s*=|\b{re.escape(name)}\s*=\s*\{{\s*url\s*=)\s*")([^"]+)(";)'
    match = re.search(pattern, original)
    if match is None:
        raise ValueError(f"cannot find flake input {name}")
    url = match[2]
    if policy == "commit":
        prefix = f"github:{repo}/"
        require_match(re.escape(prefix) + r"[0-9a-f]{40}", url, "commit-pinned input URL")
        revision = require_match(r"[0-9a-f]{40}", github(f"repos/{repo}/commits/HEAD")["sha"], "GitHub commit")
        if not has_flake_file(prefix + revision):
            raise ValueError(f"upstream commit for {repo} has no flake.nix; keeping the current pin")
    else:
        prefix = f"git+ssh://git@github.com/{repo}?ref=refs/tags/" if url.startswith("git+ssh:") else f"github:{repo}/"
        if not url.startswith(prefix):
            raise ValueError("release input URL does not match its configured repository")
        revision = latest_flake_tag(repo, prefix, url[len(prefix):])
    updated = replace_once(original, pattern, lambda m: m[1] + prefix + revision + m[3])
    save(path, original, updated)
    print(f"{name}: {prefix}{revision}")


def update_container(name):
    filename, field, repository, tag = CONTAINERS[name]
    path = ROOT / filename
    original = path.read_text()
    if tag is None:
        tags = json.loads(command("skopeo", "list-tags", f"docker://{repository}"))["Tags"]
        candidates = []
        for candidate in tags:
            match = re.fullmatch(r"2\.(\d+)\.(\d+)(?:-beta\.(\d+))?", candidate)
            if match:
                candidates.append(((int(match[1]), int(match[2]), match[3] is None, int(match[3] or 0)), candidate))
        if not candidates:
            raise ValueError("no Executor v2 release tags found; check the registry")
        tag = max(candidates)[1]
    # Hash the registry's exact manifest bytes, including multi-platform indexes.
    # Inspect by that digest afterwards so a moving tag cannot race the platform check.
    raw = command("skopeo", "inspect", "--raw", f"docker://{repository}:{tag}")
    manifest = json.loads(raw)
    if not isinstance(manifest, dict) or manifest.get("schemaVersion") != 2:
        raise ValueError("expected a v2 OCI/Docker manifest")
    digest = "sha256:" + hashlib.sha256(raw).hexdigest()
    image = f"{repository}@{digest}"
    metadata = json.loads(command("skopeo", "inspect", "--override-os", "linux", "--override-arch", "amd64", f"docker://{image}"))
    if not isinstance(metadata, dict) or metadata.get("Os") != "linux" or metadata.get("Architecture") != "amd64":
        raise ValueError("container has no linux/amd64 image for Kim")
    pattern = rf'({re.escape(field)} = "){re.escape(repository)}@sha256:[0-9a-f]{{64}}(";)'
    updated = replace_once(original, pattern, lambda m: m[1] + image + m[2])
    save(path, original, updated)
    print(f"{name}: {tag} -> {image}")


def prefetch(url):
    result = json.loads(command("nix", "store", "prefetch-file", "--json", url, timeout=1800))
    return require_match(SRI, result["hash"], "prefetched SHA-256 SRI hash")


def update_fish_plugin(name):
    repository = FISH_PLUGINS[name]
    path = ROOT / "users/maxpw/modules/shells.nix"
    original = path.read_text()
    result = json.loads(command("nix", "flake", "prefetch", "--json", f"github:{repository}"))
    revision = require_match(r"[0-9a-f]{40}", result["locked"]["rev"], "Fish plugin revision")
    hash_value = require_match(SRI, result["hash"], "Fish plugin hash")
    owner, repo = repository.split("/")
    pattern = rf'(owner = "{owner}";\s*repo = "{repo}";\s*rev = ")[^"]+(";\s*sha256 = ")[^"]+(";)'
    updated = replace_once(original, pattern, lambda m: m[1] + revision + m[2] + hash_value + m[3])
    save(path, original, updated)
    print(f"{name}: {revision}")


def update_agent_plugins():
    version = command("nix", "eval", "--raw", ".#packages.x86_64-linux.plannotator.version").decode().strip()
    require_match(r"\d+\.\d+\.\d+", version, "locked Plannotator version")
    changes = []
    for filename, pattern, value in [
        ("users/maxpw/agents/claude/settings.json", r'("repo":\s*"backnotprop/plannotator",\s*"ref":\s*")[^"]+("\s*)', "v" + version),
        ("users/maxpw/agents/opencode/cliproxyapi.json", r'("@plannotator/opencode@)[^"]+("\s*)', version),
    ]:
        path = ROOT / filename
        original = path.read_text()
        updated = replace_once(original, pattern, lambda m: m[1] + value + m[2])
        json.loads(updated)
        changes.append((path, original, updated))
    for path, original, updated in changes:
        save(path, original, updated)
    print(f"agent-plugins: Plannotator {version} (matching the locked CLI)")


def package_version(text):
    matches = re.findall(r'^  version = "([^"]+)";', text, re.MULTILINE)
    if len(matches) != 1:
        raise ValueError("expected one package version")
    return matches[0]


def update_obsidian():
    path = ROOT / "packages/obsidian.nix"
    original = path.read_text()
    tag = stable_tags("obsidianmd/obsidian-releases")[0]
    version = tag.removeprefix("v")
    if stable_version(version) < stable_version(package_version(original)):
        raise ValueError("Obsidian release is older than current pin; refusing downgrade")
    updated = replace_once(original, r'^(  version = ")[^"]+(";)', lambda m: m[1] + version + m[2])
    # Fetch both even at the same version, repairing any previously stale platform hash.
    for extension in ("AppImage", "dmg"):
        hash_value = prefetch(f"https://github.com/obsidianmd/obsidian-releases/releases/download/{tag}/Obsidian-{version}.{extension}")
        pattern = rf'(url = "\$\{{releases\}}/Obsidian-\$\{{version\}}\.{extension}";\s*hash = ")[^"]+(";)'
        updated = replace_once(updated, pattern, lambda m: m[1] + hash_value + m[2])
    save(path, original, updated)
    print(f"obsidian: {version} (Linux and macOS)")


def update_herdr_core():
    path = ROOT / "packages/herdr-core.nix"
    original = path.read_text()
    release = fetch_json("https://releases.herdr.dev/core/latest.json")
    version = require_match(r"\d+\.\d+\.\d+", release["version"], "Herdr Core version")
    if stable_version(version) < stable_version(package_version(original)):
        raise ValueError("Herdr Core release is older than current pin; refusing downgrade")
    updated = replace_once(original, r'^(  version = ")[^"]+(";)', lambda m: m[1] + version + m[2])
    for target in ("macos-aarch64", "macos-x86_64", "linux-aarch64", "linux-x86_64"):
        url = f"https://releases.herdr.dev/core/{version}/herdr-core-{target}.tar.gz"
        artifact = release["targets"][target]
        if artifact["url"] != url:
            raise ValueError(f"unexpected Herdr Core artifact URL for {target}")
        expected = require_match(r"[0-9a-f]{64}", artifact["sha256"], "Herdr Core checksum")
        hash_value = prefetch(url)
        if hash_value != "sha256-" + base64.b64encode(bytes.fromhex(expected)).decode():
            raise ValueError(f"Herdr Core checksum mismatch for {target}")
        pattern = rf'(target = "{target}";\s*hash = ")[^"]+(";)'
        updated = replace_once(updated, pattern, lambda m: m[1] + hash_value + m[2])
    save(path, original, updated)
    print(f"herdr-core: {version} (all four platforms)")


def update_plex():
    path = ROOT / "overlays.nix"
    original = path.read_text()
    release = fetch_json("https://plex.tv/api/downloads/5.json")["computer"]["Linux"]
    version = require_match(r"\d+\.\d+\.\d+\.\d+-[0-9a-f]+", release["version"], "Plex version")
    pattern = r'(plexRaw = prev\.plexRaw\.overrideAttrs \(_: let\s*version = ")([^"]+)(";)'
    current = re.search(pattern, original)
    if current is None:
        raise ValueError("cannot find Plex version")
    if stable_version(version.split("-")[0]) < stable_version(current[2].split("-")[0]):
        raise ValueError("Plex release is older than current pin; refusing downgrade")
    artifacts = release["releases"]
    if not isinstance(artifacts, list) or not all(isinstance(artifact, dict) for artifact in artifacts):
        raise ValueError("expected a Plex artifact list")
    url = f"https://downloads.plex.tv/plex-media-server-new/{version}/debian/plexmediaserver_{version}_amd64.deb"
    if not any(artifact.get("url") == url for artifact in artifacts):
        raise ValueError("Plex release has no Debian amd64 artifact")
    hash_value = prefetch(url)
    updated = replace_once(original, pattern, lambda m: m[1] + version + m[3])
    pattern = r'(url = "https://downloads\.plex\.tv/[^"\n]+";\s*sha256 = ")[^"]+(";)'
    updated = replace_once(updated, pattern, lambda m: m[1] + hash_value + m[2])
    save(path, original, updated)
    print(f"plex: {version}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("group", choices=["flake-inputs", "containers", "fish-plugins", "agent-plugins", "obsidian", "herdr-core", "plex"])
    args = parser.parse_args()
    if args.group == "flake-inputs":
        tasks = [(name, lambda name=name: update_flake_input(name)) for name in FLAKE_INPUTS]
    elif args.group == "containers":
        tasks = [(name, lambda name=name: update_container(name)) for name in CONTAINERS]
    elif args.group == "fish-plugins":
        tasks = [(name, lambda name=name: update_fish_plugin(name)) for name in FISH_PLUGINS]
    else:
        tasks = [(args.group, {"agent-plugins": update_agent_plugins, "obsidian": update_obsidian, "herdr-core": update_herdr_core, "plex": update_plex}[args.group])]
    failed = []
    for name, update in tasks:
        try:
            update()
        except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
            print(f"Source pin update failed: {name}: {error}. Review partial changes and retry this group.", file=sys.stderr)
            failed.append(name)
    if failed:
        print(f"Source pin updates incomplete: {', '.join(failed)}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
