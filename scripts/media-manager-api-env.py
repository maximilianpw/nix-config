"""Pass Servarr API keys from systemd credentials to a child process."""

import argparse
import os
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api-key", action="append", default=[])
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    if not command or not Path(command[0]).is_absolute():
        parser.error("an absolute executable path is required")
    credentials = os.environ.get("CREDENTIALS_DIRECTORY")
    if not credentials:
        parser.error("CREDENTIALS_DIRECTORY must be set")

    for mapping in args.api_key:
        variable, separator, name = mapping.partition("=")
        if (
            not separator
            or not re.fullmatch(r"[A-Z][A-Z0-9_]*", variable)
            or not re.fullmatch(r"[a-z][a-z0-9-]*", name)
        ):
            parser.error("invalid API key credential mapping")
        try:
            key = ET.parse(Path(credentials) / name).getroot().findtext("ApiKey")
            if key is None or not re.fullmatch(r"[a-fA-F0-9]{32}", key.strip()):
                raise ValueError("invalid API key")
        except (OSError, ET.ParseError, ValueError):
            # Parser details can include source content. Never log them.
            print(f"Media manager credential {name} is missing or invalid", file=sys.stderr)
            return 1
        os.environ[variable] = key.strip()

    os.execv(command[0], command)
    return 0


if __name__ == "__main__":
    sys.exit(main())
