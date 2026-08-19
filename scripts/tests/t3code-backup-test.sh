#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
backup="$repo_root/scripts/t3code-backup.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
source_dir="$tmp/source"
backup_dir="$tmp/backup"
mkdir -p "$source_dir/userdata/secrets" "$source_dir/userdata/logs" "$source_dir/caches"
printf 'secret\n' > "$source_dir/userdata/secrets/key"
printf 'first log\n' > "$source_dir/userdata/logs/server.log"
printf 'cache\n' > "$source_dir/caches/provider.json"
printf 'stale wal\n' > "$source_dir/userdata/state.sqlite-wal"
printf 'stale shm\n' > "$source_dir/userdata/state.sqlite-shm"

python3 - "$source_dir/userdata/state.sqlite" <<'PY'
import sqlite3
import sys
connection = sqlite3.connect(sys.argv[1])
connection.execute("create table threads (id integer primary key, title text)")
connection.execute("insert into threads (title) values ('first')")
connection.commit()
PY

cat > "$tmp/sqlite3" <<'PY'
#!/usr/bin/env python3
import os
import re
import sqlite3
import sys
source, statement = sys.argv[1:]
if statement.startswith(".backup "):
    if os.environ.get("FAIL_BACKUP") == "1":
        raise SystemExit(1)
    match = re.fullmatch(r"\.backup '(.+)'", statement)
    if not match:
        raise SystemExit(2)
    with sqlite3.connect(source) as source_db, sqlite3.connect(match.group(1)) as destination_db:
        source_db.backup(destination_db)
elif statement == "PRAGMA integrity_check;":
    with sqlite3.connect(source) as connection:
        print(connection.execute(statement).fetchone()[0])
else:
    raise SystemExit(2)
PY
chmod +x "$tmp/sqlite3"

run_backup() {
  T3CODE_SOURCE_DIR=$source_dir \
    T3CODE_BACKUP_DIR=$backup_dir \
    SQLITE_BIN=$tmp/sqlite3 \
    RSYNC_BIN=$(command -v rsync) \
    TAR_BIN=$(command -v tar) \
    bash "$backup"
}

run_backup
[[ -s $backup_dir/state.tar ]]
mkdir "$tmp/extracted"
tar -xf "$backup_dir/state.tar" -C "$tmp/extracted"
grep -Fxq secret "$tmp/extracted/userdata/secrets/key"
grep -Fxq 'first log' "$tmp/extracted/userdata/logs/server.log"
[[ ! -e $tmp/extracted/userdata/state.sqlite-wal ]]
[[ ! -e $tmp/extracted/userdata/state.sqlite-shm ]]
python3 - "$tmp/extracted/userdata/state.sqlite" <<'PY'
import sqlite3
import sys
with sqlite3.connect(sys.argv[1]) as connection:
    assert connection.execute("pragma integrity_check").fetchone()[0] == "ok"
    assert connection.execute("select title from threads").fetchall() == [("first",)]
PY

python3 - "$source_dir/userdata/state.sqlite" <<'PY'
import sqlite3
import sys
with sqlite3.connect(sys.argv[1]) as connection:
    connection.execute("insert into threads (title) values ('second')")
PY
rm "$source_dir/userdata/logs/server.log"
printf 'attachment\n' > "$source_dir/userdata/attachment"
run_backup
rm -rf "$tmp/extracted"
mkdir "$tmp/extracted"
tar -xf "$backup_dir/state.tar" -C "$tmp/extracted"
[[ ! -e $tmp/extracted/userdata/logs/server.log ]]
grep -Fxq attachment "$tmp/extracted/userdata/attachment"
python3 - "$tmp/extracted/userdata/state.sqlite" <<'PY'
import sqlite3
import sys
with sqlite3.connect(sys.argv[1]) as connection:
    assert connection.execute("select title from threads order by id").fetchall() == [("first",), ("second",)]
PY

archive_hash=$(sha256sum "$backup_dir/state.tar")
if FAIL_BACKUP=1 run_backup; then
  echo "failed SQLite snapshot unexpectedly replaced the T3 Code archive" >&2
  exit 1
fi
[[ $archive_hash == "$(sha256sum "$backup_dir/state.tar")" ]]
[[ ! -e $backup_dir/state.tar.tmp ]]

echo "T3 Code online backup tests passed"
