#!/usr/bin/env python3
"""Export storage error counts from the last 15 minutes of retained kernel logs.

Rolling-window gauges, not lifetime counters. Never emit raw journal messages
or device names. Ordinary USB disconnects/resets are not necessarily faults.
"""

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


ERROR_PATTERNS = {
    "journal_abort": re.compile(r"\bAborting journal\b", re.IGNORECASE),
    "filesystem_error": re.compile(r"\b(?:EXT4|XFS|BTRFS)-fs (?:error|corruption)\b", re.IGNORECASE),
    "io_error": re.compile(r"\b(?:I/O error|lost async page write)\b", re.IGNORECASE),
}


def collect():
    journalctl = os.environ["JOURNALCTL_BIN"]
    metrics_directory = Path(os.environ["HOMELAB_METRICS_DIR"])
    result = subprocess.run(
        [journalctl, "--quiet", "--no-pager", "--output=json", "--since=-15min", "_TRANSPORT=kernel"],
        capture_output=True,
        text=True,
        timeout=30,
    )
    if result.returncode != 0:
        raise RuntimeError("journal query failed")
    counts = dict.fromkeys(ERROR_PATTERNS, 0)
    for line in result.stdout.splitlines():
        if not line.strip():
            continue
        entry = json.loads(line)
        if not isinstance(entry, dict):
            raise RuntimeError("invalid journal entry")
        message = entry.get("MESSAGE")
        if not isinstance(message, str):
            continue
        # One category per message prevents counting an aborted filesystem
        # journal as a second generic I/O error.
        for kind, pattern in ERROR_PATTERNS.items():
            if pattern.search(message):
                counts[kind] += 1
                break
    destination = metrics_directory / "homelab-storage-kernel.prom"
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", dir=metrics_directory, prefix=".homelab-storage-kernel-", delete=False
        ) as output:
            temporary = Path(output.name)
            output.write("# HELP homelab_storage_kernel_errors Storage error messages in retained kernel logs over the last 15 minutes.\n")
            output.write("# TYPE homelab_storage_kernel_errors gauge\n")
            for kind, count in counts.items():
                output.write(f'homelab_storage_kernel_errors{{kind="{kind}"}} {count}\n')
        temporary.chmod(0o644)
        temporary.replace(destination)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        collect()
    except (KeyError, OSError, ValueError, RuntimeError, subprocess.TimeoutExpired):
        # Neither exceptions nor child stderr are safe to quote: journal data
        # can contain request URLs or credential-bearing application payloads.
        print("storage kernel metrics: collection failed; previous sample preserved", file=sys.stderr)
        sys.exit(1)
