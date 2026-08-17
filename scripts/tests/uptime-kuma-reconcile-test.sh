#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
script="$repo_root/scripts/uptime-kuma-reconcile.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

db="$tmp/kuma.db"
fake_sqlite="$tmp/sqlite3"
cat > "$fake_sqlite" <<'EOF'
#!/usr/bin/env python3
import pathlib
import re
import shutil
import sqlite3
import sys

database, statement = sys.argv[1:3]
if statement.startswith(".backup "):
    match = re.fullmatch(r"\.backup '(.+)'", statement)
    if not match:
        raise SystemExit("invalid backup command")
    source = sqlite3.connect(database)
    destination = sqlite3.connect(match.group(1))
    source.backup(destination)
    destination.close()
    source.close()
else:
    connection = sqlite3.connect(database)
    cursor = connection.executescript(statement) if ";" in statement.strip().rstrip(";") else connection.execute(statement)
    if cursor.description:
        for row in cursor:
            print("|".join("" if value is None else str(value) for value in row))
    connection.commit()
    connection.close()
EOF
chmod +x "$fake_sqlite"

python3 - "$db" <<'PY'
import sqlite3
import sys
connection = sqlite3.connect(sys.argv[1])
connection.executescript("""
CREATE TABLE monitor (id INTEGER PRIMARY KEY, name TEXT, type TEXT, url TEXT, hostname TEXT, port INTEGER);
INSERT INTO monitor (name, type, hostname, port) VALUES ('Syncthing transport', 'port', '127.0.0.1', 22000);
INSERT INTO monitor (name, type, url) VALUES ('Other', 'http', 'http://127.0.0.1:1234/health');
""")
connection.commit()
PY

SQLITE_BIN="$fake_sqlite" UPTIME_KUMA_DB="$db" "$script" >/dev/null
actual=$(python3 - "$db" <<'PY'
import sqlite3
import sys
row = sqlite3.connect(sys.argv[1]).execute("SELECT type, url, ifnull(hostname, ''), ifnull(port, '') FROM monitor WHERE name = 'Syncthing transport'").fetchone()
print("|".join(str(value) for value in row))
PY
)
test "$actual" = 'http|http://127.0.0.1:19384/rest/noauth/health||'
test -f "$db.pre-syncthing-http-monitor"

backup_hash=$(sha256sum "$db.pre-syncthing-http-monitor")
SQLITE_BIN="$fake_sqlite" UPTIME_KUMA_DB="$db" "$script" >/dev/null
test "$backup_hash" = "$(sha256sum "$db.pre-syncthing-http-monitor")"

python3 - "$db" <<'PY'
import sqlite3
import sys
connection = sqlite3.connect(sys.argv[1])
connection.executescript("""
INSERT INTO monitor (name, type, hostname, port) VALUES ('Syncthing duplicate one', 'port', 'localhost', 22000);
INSERT INTO monitor (name, type, hostname, port) VALUES ('Syncthing duplicate two', 'port', '127.0.0.1', 22000);
""")
connection.commit()
PY
if SQLITE_BIN="$fake_sqlite" UPTIME_KUMA_DB="$db" "$script" >/dev/null 2>&1; then
  echo "ambiguous Syncthing monitors were unexpectedly reconciled" >&2
  exit 1
fi
count=$(python3 - "$db" <<'PY'
import sqlite3
import sys
print(sqlite3.connect(sys.argv[1]).execute("SELECT count(*) FROM monitor WHERE type = 'port' AND port = 22000").fetchone()[0])
PY
)
test "$count" = 2

echo "uptime kuma reconcile tests passed"
