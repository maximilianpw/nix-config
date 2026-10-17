#!/usr/bin/env bash
# Read-only SMART passthrough verification; no SMART enable/self-test/repair.
set -euo pipefail
: "${SMARTCTL_BIN:?SMARTCTL_BIN must be set}"
: "${JQ_BIN:?JQ_BIN must be set}"
: "${HOMELAB_MEDIA_SMART_DEVICE:?HOMELAB_MEDIA_SMART_DEVICE must be set}"

status=0
telemetry=$("$SMARTCTL_BIN" --all --json --device=sat "$HOMELAB_MEDIA_SMART_DEVICE" 2>/dev/null) || status=$?
if (( (status & 7) != 0 )); then
  echo 'media SMART check: read/passthrough failed; disk health is unknown and exporter coverage must not be enabled yet' >&2
  exit 1
fi
if ! "$JQ_BIN" -e '(.smart_status.passed | type) == "boolean"' <<< "$telemetry" >/dev/null 2>&1; then
  echo 'media SMART check: no verified SMART status; disk health remains unknown' >&2
  exit 1
fi
# Omit serial numbers, device topology and raw smartctl messages.
"$JQ_BIN" '{
  smartPassed: .smart_status.passed,
  temperatureCelsius: (.temperature.current // null),
  attributes: [.ata_smart_attributes.table[]? |
    select(.id == 5 or .id == 187 or .id == 197 or .id == 198 or .id == 199) |
    {id, name, rawValue: .raw.value}]
}' <<< "$telemetry"
if (( status != 0 )) || ! "$JQ_BIN" -e '.smart_status.passed == true' <<< "$telemetry" >/dev/null; then
  echo 'media SMART check: SMART health/history reports a problem; preserve independent copies and investigate before repair' >&2
  exit 1
fi
echo 'media SMART check: read-only SAT passthrough and SMART status verified; this is not a filesystem integrity test'
