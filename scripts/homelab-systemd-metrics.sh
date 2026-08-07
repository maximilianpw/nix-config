#!/usr/bin/env bash

set -euo pipefail

: "${SYSTEMCTL_BIN:=systemctl}"
: "${AWK_BIN:=awk}"
: "${HOMELAB_METRICS_DIR:=/var/lib/prometheus-node-exporter-text-files}"

if (( $# == 0 )); then
  echo "homelab-systemd-metrics requires at least one systemd unit" >&2
  exit 2
fi

metrics_file="${HOMELAB_METRICS_DIR}/homelab-systemd-resources.prom"
metrics_tmp="$(mktemp "${metrics_file}.XXXXXX")"

cleanup() {
  rm -f "$metrics_tmp"
}
trap cleanup EXIT

{
  printf '# HELP homelab_systemd_unit_cpu_seconds_total CPU time consumed by a systemd unit.\n'
  printf '# TYPE homelab_systemd_unit_cpu_seconds_total counter\n'
  "$SYSTEMCTL_BIN" show --property=Id --property=CPUUsageNSec "$@" |
    "$AWK_BIN" -F= '
      function escape_label(value) {
        gsub(/\\/, "\\\\", value)
        gsub(/"/, "\\\"", value)
        return value
      }

      $1 == "Id" {
        unit = substr($0, 4)
        next
      }

      $1 == "CPUUsageNSec" && $2 ~ /^[0-9]+$/ && unit != "" {
        printf "homelab_systemd_unit_cpu_seconds_total{unit=\"%s\"} %.9f\n", escape_label(unit), $2 / 1000000000
        unit = ""
      }
    '
} > "$metrics_tmp"

chmod 0644 "$metrics_tmp"
mv -f "$metrics_tmp" "$metrics_file"
trap - EXIT
