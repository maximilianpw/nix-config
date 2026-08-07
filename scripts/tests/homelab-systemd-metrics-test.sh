#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

metrics_dir="$test_root/metrics"
fake_systemctl="$test_root/systemctl"
mkdir -p "$metrics_dir"

cat > "$fake_systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

expected=(
  show
  --property=Id
  --property=CPUUsageNSec
  immich-server.service
  jellyfin.service
  inactive.service
)

if [[ "$*" != "${expected[*]}" ]]; then
  printf 'unexpected systemctl arguments: %s\n' "$*" >&2
  exit 1
fi

if [[ "${FAIL_SYSTEMCTL:-0}" == 1 ]]; then
  printf 'Id=partial.service\nCPUUsageNSec=1\n'
  exit 1
fi

cat <<'METRICS'
Id=immich-server.service
CPUUsageNSec=1234567890

Id=inactive.service
CPUUsageNSec=[not set]

Id=jellyfin.service
CPUUsageNSec=9000000000
METRICS
EOF
chmod +x "$fake_systemctl"

SYSTEMCTL_BIN="$fake_systemctl" \
  HOMELAB_METRICS_DIR="$metrics_dir" \
  "$script_dir/homelab-systemd-metrics.sh" \
  immich-server.service \
  jellyfin.service \
  inactive.service

metrics_file="$metrics_dir/homelab-systemd-resources.prom"
expected_metrics="$test_root/expected.prom"
cat > "$expected_metrics" <<'EOF'
# HELP homelab_systemd_unit_cpu_seconds_total CPU time consumed by a systemd unit.
# TYPE homelab_systemd_unit_cpu_seconds_total counter
homelab_systemd_unit_cpu_seconds_total{unit="immich-server.service"} 1.234567890
homelab_systemd_unit_cpu_seconds_total{unit="jellyfin.service"} 9.000000000
EOF

cmp "$expected_metrics" "$metrics_file"
test "$(stat -c '%a' "$metrics_file")" = "644"
test -z "$(find "$metrics_dir" -type f ! -name 'homelab-systemd-resources.prom' -print -quit)"

if FAIL_SYSTEMCTL=1 \
  SYSTEMCTL_BIN="$fake_systemctl" \
  HOMELAB_METRICS_DIR="$metrics_dir" \
  "$script_dir/homelab-systemd-metrics.sh" \
  immich-server.service \
  jellyfin.service \
  inactive.service >/dev/null 2>&1; then
  echo "collector unexpectedly accepted a failed systemctl query" >&2
  exit 1
fi
cmp "$expected_metrics" "$metrics_file"
test -z "$(find "$metrics_dir" -type f ! -name 'homelab-systemd-resources.prom' -print -quit)"

if HOMELAB_METRICS_DIR="$metrics_dir" "$script_dir/homelab-systemd-metrics.sh" >/dev/null 2>&1; then
  echo "collector unexpectedly accepted an empty unit list" >&2
  exit 1
fi

echo "homelab systemd metrics tests passed"
