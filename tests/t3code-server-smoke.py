#!/usr/bin/env python3
"""Smoke-test a packaged T3 server using disposable state and loopback only."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request


def main():
    executable, expected_version = sys.argv[1:]
    with tempfile.TemporaryDirectory(prefix="t3code-smoke-") as directory:
        home = Path(directory)
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            port = reservation.getsockname()[1]
        environment = {
            "HOME": str(home), "PATH": os.environ["PATH"],
            "XDG_CONFIG_HOME": str(home / "config"),
            "XDG_DATA_HOME": str(home / "data"),
            "XDG_CACHE_HOME": str(home / "cache"),
            "T3CODE_DISABLE_AUTO_UPDATE": "1",
            "SHELL": os.environ.get("SHELL", "/bin/sh"),
        }
        # Do not print logs: even a disposable server emits pairing credentials.
        with (home / "server.log").open("w") as log:
            process = subprocess.Popen(
                [executable, "serve", "--host", "127.0.0.1", "--port", str(port),
                 "--base-dir", str(home / "state"), "--no-browser"],
                cwd=home, env=environment, stdout=log, stderr=log,
            )
            try:
                client = urllib.request.build_opener(urllib.request.ProxyHandler({}))
                deadline = time.monotonic() + 45
                while time.monotonic() < deadline:
                    if process.poll() is not None:
                        log.flush()
                        contents = (home / "server.log").read_text()
                        diagnostics = [marker for marker in (
                            "EPERM", "EACCES", "ENOENT", "EADDRINUSE", "Operation not permitted",
                            "git", "sandbox", "SQLITE", "keychain", "spawn", "listen",
                        ) if marker in contents]
                        raise RuntimeError(f"T3 smoke test: server exited with {process.returncode}; diagnostics: {diagnostics}")
                    try:
                        with client.open(
                            f"http://127.0.0.1:{port}/.well-known/t3/environment", timeout=2
                        ) as response:
                            metadata = json.load(response)
                        if expected_version not in json.dumps(metadata):
                            raise RuntimeError("T3 smoke test: environment reports a different version")
                        print(f"T3 server HTTP smoke test passed ({expected_version})")
                        return
                    except (urllib.error.URLError, TimeoutError, ConnectionError):
                        time.sleep(0.2)
                raise RuntimeError("T3 smoke test: server did not become healthy in 45 seconds")
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()


if __name__ == "__main__":
    main()
