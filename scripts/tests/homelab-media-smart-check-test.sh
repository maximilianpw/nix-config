#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
printf '#!%s\n' "$(command -v bash)" > "$fixture/smartctl"
cat >> "$fixture/smartctl" <<'EOF'
set -euo pipefail
[[ "$*" == '--all --json --device=sat /dev/fixture-media' ]]
printf '%s' "$SMART_FIXTURE"
exit "${SMART_EXIT:-0}"
EOF
chmod +x "$fixture/smartctl"
JQ_BIN="$(command -v jq)"
export SMARTCTL_BIN="$fixture/smartctl" JQ_BIN HOMELAB_MEDIA_SMART_DEVICE=/dev/fixture-media
export SMART_FIXTURE='{"smart_status":{"passed":true},"serial_number":"private-fixture-serial","temperature":{"current":32},"ata_smart_attributes":{"table":[{"id":197,"name":"Current_Pending_Sector","raw":{"value":0}}]}}'
bash "$script_dir/homelab-media-smart-check.sh" >"$fixture/output"
grep -F 'passthrough and SMART status verified' "$fixture/output"
! grep -q private-fixture "$fixture/output"

export SMART_EXIT=2
if bash "$script_dir/homelab-media-smart-check.sh" >"$fixture/output" 2>&1; then
  echo 'SMART probe accepted a failed read' >&2
  exit 1
fi
grep -F 'disk health is unknown' "$fixture/output"
export SMART_EXIT=0 SMART_FIXTURE='{"smartctl":{"messages":[{"string":"private-fixture-message"}]}}'
if bash "$script_dir/homelab-media-smart-check.sh" >"$fixture/output" 2>&1; then
  echo 'SMART probe accepted absent SMART status' >&2
  exit 1
fi
! grep -q private-fixture "$fixture/output"
export SMART_FIXTURE='{"smart_status":{"passed":false}}' SMART_EXIT=8
if bash "$script_dir/homelab-media-smart-check.sh" >"$fixture/output" 2>&1; then
  echo 'SMART probe accepted a failing disk' >&2
  exit 1
fi
grep -F 'SMART health/history reports a problem' "$fixture/output"
echo 'media SMART preflight tests passed'
