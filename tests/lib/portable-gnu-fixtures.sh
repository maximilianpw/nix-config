#!/usr/bin/env bash

install_portable_gnu_tar_fixture() {
  local fixture=$1

  cat > "$fixture" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 7 ]]
[[ $1 == --create ]]
[[ $2 == --sparse ]]
[[ $3 == --file ]]
[[ $5 == --directory ]]

exec "${TEST_REAL_TAR_BIN:?}" -cf "$4" -C "$6" "$7"
EOF
  chmod +x "$fixture"
}

install_portable_gnu_reference_fixtures() {
  local fixture_dir=$1
  mkdir -p "$fixture_dir"

  cat > "$fixture_dir/chown" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 2 ]]
[[ $1 == --reference=* ]]
reference=${1#--reference=}

python3 - "$reference" "$2" <<'PY'
import os
import sys

reference = os.stat(sys.argv[1])
destination = os.stat(sys.argv[2])
if (destination.st_uid, destination.st_gid) != (reference.st_uid, reference.st_gid):
    os.chown(sys.argv[2], reference.st_uid, reference.st_gid)
PY
EOF

  cat > "$fixture_dir/chmod" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 2 ]]
[[ $1 == --reference=* ]]
reference=${1#--reference=}

python3 - "$reference" "$2" <<'PY'
import os
import stat
import sys

os.chmod(sys.argv[2], stat.S_IMODE(os.stat(sys.argv[1]).st_mode))
PY
EOF

  chmod +x "$fixture_dir/chown" "$fixture_dir/chmod"
}

install_portable_gnu_date_fixture() {
  local fixture=$1

  cat > "$fixture" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 1 && $1 == +%s ]]; then
  printf '%s\n' "${TEST_NOW_EPOCH:?}"
  exit 0
fi

[[ $# -eq 2 && $1 == --date=* && $2 == +%s ]]
timestamp=${1#--date=}

python3 - "$timestamp" <<'PY'
import datetime
import sys

timestamp = datetime.datetime.fromisoformat(sys.argv[1].replace("Z", "+00:00"))
print(int(timestamp.timestamp()))
PY
EOF
  chmod +x "$fixture"
}

assert_file_mode() {
  local path=$1 expected_mode=$2

  python3 - "$path" "$expected_mode" <<'PY'
import os
import stat
import sys

actual = stat.S_IMODE(os.stat(sys.argv[1]).st_mode)
expected = int(sys.argv[2], 8)
assert actual == expected, f"expected mode {expected:o}, got {actual:o}"
PY
}
