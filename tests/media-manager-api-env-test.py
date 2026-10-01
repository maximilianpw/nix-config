"""Exercise credential handling with disposable XML files and a real child."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(sys.argv.pop()).resolve()
KEY = "0123456789abcdef" * 2


class ManagerApiEnvironmentTests(unittest.TestCase):
    def run_child(self, xml, credential_exists=True):
        with tempfile.TemporaryDirectory() as directory:
            credential = Path(directory) / "sonarr-config"
            if credential_exists:
                credential.write_text(xml)
                credential.chmod(0o400)
            environment = os.environ.copy()
            environment["CREDENTIALS_DIRECTORY"] = directory
            environment["EXISTING_SETTING"] = "preserved"
            # The probe checks the secret without emitting it.
            probe = (
                "import os, sys; "
                f"assert os.environ['SONARR_API_KEY'] == {KEY!r}; "
                "assert os.environ['EXISTING_SETTING'] == 'preserved'; "
                "assert sys.argv[1] == 'argument with spaces'; "
                "print('child verified')"
            )
            return subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--api-key",
                    "SONARR_API_KEY=sonarr-config",
                    "--",
                    sys.executable,
                    "-c",
                    probe,
                    "argument with spaces",
                ],
                env=environment,
                capture_output=True,
                text=True,
                check=False,
            )

    def test_child_receives_key_and_arguments_without_logging_secrets(self):
        result = self.run_child(f"<Config><ApiKey> {KEY} </ApiKey></Config>")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "child verified\n")
        self.assertEqual(result.stderr, "")

    def test_invalid_or_missing_credentials_fail_before_starting_child(self):
        for xml, exists in [
            (f"<Config><ApiKey>{KEY}", True),
            ("<Config><ApiKey>private-invalid-value</ApiKey></Config>", True),
            ("<Config />", True),
            ("", False),
        ]:
            with self.subTest(xml=xml, exists=exists):
                result = self.run_child(xml, exists)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(result.stdout, "")
                self.assertIn("Media manager credential sonarr-config", result.stderr)
                self.assertNotIn(KEY, result.stderr)
                self.assertNotIn("private-invalid-value", result.stderr)
                self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()
