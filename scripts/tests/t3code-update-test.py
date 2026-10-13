#!/usr/bin/env python3
"""Offline release discovery and atomic-pin regression tests."""
import importlib.util
import json
from pathlib import Path
import tempfile
import sys
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "update_t3code", Path(__file__).resolve().parents[2] / "packages/scripts/update-t3code.py"
)
updater = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(updater)
CURRENT = "0.0.46-nightly.20261003.9"
NEW = "0.0.46-nightly.20261003.10"
HASH = "sha256-" + "A" * 43 + "="


def release(version=NEW):
    return {
        "tag_name": "v" + version, "draft": False,
        "assets": [
            {"name": f"T3-Code-{version}-{suffix}", "state": "uploaded", "size": 1}
            for suffix in updater.ARTIFACTS.values()
        ],
    }


class T3CodeUpdateTest(unittest.TestCase):
    def test_paginated_discovery(self):
        first = [release(CURRENT)] * 100
        second = [release()]
        with patch.object(updater.subprocess, "run") as run:
            run.side_effect = [
                updater.subprocess.CompletedProcess([], 0, json.dumps(first)),
                updater.subprocess.CompletedProcess([], 0, json.dumps(second)),
            ]
            self.assertEqual(len(updater.discover_releases()), 101)
            self.assertIn("page=2", run.call_args.args[0][-1])

    def test_discovery_failure_does_not_update_manifest(self):
        with patch.object(updater, "discover_releases", side_effect=RuntimeError("API failed")):
            with patch.object(updater, "update_manifest") as update:
                with patch.object(sys, "argv", ["update-t3code.py"]):
                    with self.assertRaisesRegex(RuntimeError, "API failed"):
                        updater.main()
                update.assert_not_called()

    def test_numeric_order_not_api_order(self):
        newer = "0.0.46-nightly.20261004.1"
        self.assertEqual(updater.select_release([release(newer), release(), release(CURRENT)], CURRENT)[0], newer)
        self.assertEqual(updater.select_release([release()], CURRENT)[0], NEW)

    def test_skip_drafts_stable_partial_and_empty_assets(self):
        draft = release()
        draft["draft"] = True
        partial = release()
        partial["assets"].pop()
        empty = release()
        empty["assets"][0]["size"] = 0
        uploading = release()
        uploading["assets"][0]["state"] = "new"
        self.assertIsNone(updater.select_release([draft, release("0.0.99"), partial, empty, uploading], CURRENT))

    def test_no_downgrade_or_rehash_current(self):
        self.assertIsNone(updater.select_release([release(CURRENT)], NEW))
        self.assertIsNone(updater.select_release([release(CURRENT)], CURRENT))

    def test_complete_pin_and_download_urls(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "release.json"
            path.write_text(json.dumps({"version": CURRENT, "sources": {}}))
            urls = []
            def prefetch(url):
                urls.append(url)
                return HASH
            self.assertTrue(updater.update_manifest(path, [release()], prefetch))
            data = json.loads(path.read_text())
            self.assertEqual(data["version"], NEW)
            self.assertEqual(set(data["sources"]), set(updater.ARTIFACTS))
            self.assertEqual(len(urls), 2)
            self.assertTrue(all(url.startswith(updater.DOWNLOAD_URL + "/v" + NEW + "/") for url in urls))
            self.assertFalse(updater.update_manifest(path, [release()], lambda _: self.fail("unexpected fetch")))

    def test_failed_second_download_preserves_pin(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "release.json"
            original = json.dumps({"version": CURRENT, "sources": {}})
            path.write_text(original)
            with patch.object(updater, "prefetch_hash", side_effect=[HASH, RuntimeError("download failed")]) as prefetch:
                with self.assertRaises(RuntimeError):
                    updater.update_manifest(path, [release()], prefetch)
            self.assertEqual(path.read_text(), original)
            self.assertEqual(list(Path(directory).iterdir()), [path])

    def test_digest_mismatch_preserves_pin(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "release.json"
            original = json.dumps({"version": CURRENT, "sources": {}})
            path.write_text(original)
            candidate = release()
            candidate["assets"][0]["digest"] = "sha256:" + "ff" * 32
            with self.assertRaisesRegex(ValueError, "digest mismatch"):
                updater.update_manifest(path, [candidate], lambda _: HASH)
            self.assertEqual(path.read_text(), original)

    def test_concurrent_edit_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "release.json"
            path.write_text(json.dumps({"version": CURRENT, "sources": {}}))
            def prefetch(_):
                path.write_text("operator edit")
                return HASH
            with self.assertRaisesRegex(RuntimeError, "manifest changed"):
                updater.update_manifest(path, [release()], prefetch)
            self.assertEqual(path.read_text(), "operator edit")


if __name__ == "__main__":
    unittest.main()
