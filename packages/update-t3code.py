#!/usr/bin/env python3
"""Discover complete upstream T3 nightlies; atomically replace the shared pin."""

import argparse
import base64
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

RELEASES_API = "repos/pingdotgg/t3code/releases"
DOWNLOAD_URL = "https://github.com/pingdotgg/t3code/releases/download"
ARTIFACTS = {"aarch64-darwin": "arm64.zip", "x86_64-linux": "x86_64.AppImage"}
VERSION = re.compile(r"(\d+)\.(\d+)\.(\d+)-nightly\.(\d{8})\.(\d+)")
MANIFEST = Path(__file__).resolve().parents[1] / "t3code-release.json"


def version_key(version):
    match = VERSION.fullmatch(version)
    if not match:
        raise ValueError(f"T3 release: invalid nightly version {version!r}")
    return tuple(map(int, match.groups()))


def discover_releases():
    # A bounded window, not /releases/latest (which excludes prereleases).
    releases = []
    for page in range(1, 11):
        response = subprocess.run(
            ["gh", "api", f"{RELEASES_API}?per_page=100&page={page}"],
            check=True, text=True, capture_output=True, timeout=60,
        )
        batch = json.loads(response.stdout)
        if not isinstance(batch, list):
            raise ValueError("T3 release: expected a GitHub release list")
        releases.extend(batch)
        if len(batch) < 100:
            break
    return releases


def select_release(releases, current_version):
    candidates = []
    for release in releases:
        tag = release.get("tag_name", "")
        if release.get("draft") or not tag.startswith("v") or not VERSION.fullmatch(tag[1:]):
            continue
        version = tag[1:]
        if version_key(version) <= version_key(current_version):
            continue
        assets = {asset["name"]: asset for asset in release.get("assets", [])}
        required = {system: assets.get(f"T3-Code-{version}-{suffix}") for system, suffix in ARTIFACTS.items()}
        if all(asset and asset.get("state") == "uploaded" and asset.get("size", 0) > 0 for asset in required.values()):
            candidates.append((version, required))
    return max(candidates, key=lambda candidate: version_key(candidate[0]), default=None)


def prefetch_hash(url):
    result = subprocess.run(
        ["nix", "store", "prefetch-file", "--json", url],
        check=True, text=True, capture_output=True,
    )
    return json.loads(result.stdout)["hash"]


def update_manifest(path, releases, prefetch=prefetch_hash):
    original = path.read_bytes()
    current = json.loads(original)
    selected = select_release(releases, current["version"])
    if selected is None:
        print(f"T3 Code: no newer complete nightly found; keeping {current['version']}")
        return False
    version, assets = selected
    sources = {}
    for system, suffix in ARTIFACTS.items():
        # Construct the URL ourselves: never download arbitrary URLs from API data.
        url = f"{DOWNLOAD_URL}/v{version}/T3-Code-{version}-{suffix}"
        hash_value = prefetch(url)
        if not re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", hash_value):
            raise ValueError("T3 release: prefetch returned an invalid SHA-256 SRI hash")
        digest = assets[system].get("digest")
        if digest and digest.startswith("sha256:"):
            expected = "sha256-" + base64.b64encode(bytes.fromhex(digest[7:])).decode()
            if hash_value != expected:
                raise ValueError(f"T3 release: GitHub digest mismatch for {system}")
        sources[system] = {"hash": hash_value}
    # Do not leave a half-updated pin if either download failed. Refuse to
    # overwrite edits made while downloading. The temp file is on the same FS.
    if path.read_bytes() != original:
        raise RuntimeError("T3 release: manifest changed during download; retry")
    updated = json.dumps({"version": version, "sources": sources}, indent=2) + "\n"
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
    print(f"T3 Code: {current['version']} -> {version}; build and verify before activating")
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    update_manifest(MANIFEST, discover_releases())


if __name__ == "__main__":
    main()
