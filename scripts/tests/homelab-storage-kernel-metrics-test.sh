#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir "$fixture/metrics"
printf '#!%s\n' "$(command -v bash)" > "$fixture/journalctl"
cat >> "$fixture/journalctl" <<'EOF'
set -euo pipefail
[[ "$*" == '--quiet --no-pager --output=json --since=-15min _TRANSPORT=kernel' ]]
[[ ${FAIL_JOURNAL:-0} != 1 ]] || exit 1
printf '%s\n' "${JOURNAL_FIXTURE:-}"
EOF
chmod +x "$fixture/journalctl"
export JOURNALCTL_BIN="$fixture/journalctl"
export HOMELAB_METRICS_DIR="$fixture/metrics"
metrics="$HOMELAB_METRICS_DIR/homelab-storage-kernel.prom"

export JOURNAL_FIXTURE='{"MESSAGE":"I/O error, dev sdb, sector 123"}
{"MESSAGE":"Buffer I/O error on dev sdb2, lost async page write"}
{"MESSAGE":"EXT4-fs error (device sdb2): filesystem failed"}
{"MESSAGE":"Aborting journal on device sdb2-8."}
{"MESSAGE":"USB keyboard disconnected"}
{"MESSAGE":"private synthetic fixture text must never reach metrics"}
{"MESSAGE":["not a journal string"]}'
python3 "$script_dir/homelab/homelab-storage-kernel-metrics.py"
grep -Fx 'homelab_storage_kernel_errors{kind="io_error"} 2' "$metrics"
grep -Fx 'homelab_storage_kernel_errors{kind="filesystem_error"} 1' "$metrics"
grep -Fx 'homelab_storage_kernel_errors{kind="journal_abort"} 1' "$metrics"
if grep -Eq 'synthetic|sector|sdb|keyboard' "$metrics"; then
  echo 'kernel collector leaked raw journal data or counted an ordinary USB event' >&2
  exit 1
fi

# A healthy refresh clears the rolling-window gauges.
export JOURNAL_FIXTURE='{"MESSAGE":"ordinary kernel message"}'
python3 "$script_dir/homelab/homelab-storage-kernel-metrics.py"
[[ $(grep -c '} 0$' "$metrics") == 3 ]]
cp "$metrics" "$fixture/previous"

# A failed or malformed journal read must leave the last complete sample intact
# so the textfile freshness alert can expose a broken collector.
export FAIL_JOURNAL=1
if python3 "$script_dir/homelab/homelab-storage-kernel-metrics.py" 2>"$fixture/error"; then
  echo 'collector succeeded after journal failure' >&2
  exit 1
fi
cmp "$metrics" "$fixture/previous"
unset FAIL_JOURNAL
export JOURNAL_FIXTURE='invalid JSON with private synthetic fixture text'
if python3 "$script_dir/homelab/homelab-storage-kernel-metrics.py" 2>"$fixture/error"; then
  echo 'collector succeeded on malformed journal JSON' >&2
  exit 1
fi
cmp "$metrics" "$fixture/previous"
! grep -q 'synthetic' "$fixture/error"
[[ $(find "$HOMELAB_METRICS_DIR" -type f | wc -l) == 1 ]]
echo 'storage kernel metrics tests passed'
