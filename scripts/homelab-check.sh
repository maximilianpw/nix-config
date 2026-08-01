#!/usr/bin/env bash
# Read-only homelab runtime smoke check. It never restarts, mounts, clears, or restores.
set -uo pipefail

: "${FINDMNT_BIN:=findmnt}"
: "${SYSTEMCTL_BIN:=systemctl}"
: "${SS_BIN:=ss}"
: "${TAILSCALE_BIN:=tailscale}"
: "${JQ_BIN:=jq}"
: "${CURL_BIN:=curl}"
: "${ID_BIN:=id}"

failures=0
fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

printf '%s\n' '== mounts =='
read -r -a required_mounts <<< "${HOMELAB_REQUIRED_MOUNTS:-/srv}"
read -r -a optional_automounts <<< "${HOMELAB_OPTIONAL_AUTOMOUNTS:-}"
for mount in "${required_mounts[@]}"; do
  if ! details=$($FINDMNT_BIN -rn -M "$mount" -o SOURCE,FSTYPE,TARGET 2>/dev/null); then
    fail "$mount is not a mount point"
  else
    printf '%s\n' "$details"
    if awk '$2 == "autofs" { found = 1 } END { exit !found }' <<< "$details"; then
      if [[ " ${optional_automounts[*]} " == *" $mount "* ]]; then
        printf 'INFO: %s is armed but not mounted; no access was triggered\n' "$mount"
      else
        fail "$mount resolved only to an automount, not its backing filesystem"
      fi
    fi
  fi
done

printf '%s\n' '== failed important units =='
read -r -a important_units <<< "${HOMELAB_IMPORTANT_UNITS:-}"
for unit in "${important_units[@]}"; do
  if $SYSTEMCTL_BIN is-failed --quiet "$unit" 2>/dev/null; then
    fail "$unit is failed"
  fi
done
$SYSTEMCTL_BIN --failed --no-legend --plain 2>/dev/null || true

printf '%s\n' '== declared loopback listeners =='
read -r -a loopback_ports <<< "${HOMELAB_LOOPBACK_PORTS:-}"
for port in "${loopback_ports[@]}"; do
  listeners=$($SS_BIN -H -lnt "sport = :$port" 2>/dev/null || true)
  if [[ -z $listeners ]]; then
    fail "declared port $port has no TCP listener"
  elif awk '{print $4}' <<< "$listeners" | grep -Evq '^(127\.0\.0\.1|\[::1\]):[0-9]+$'; then
    fail "declared port $port has a non-loopback listener"
    printf '%s\n' "$listeners" >&2
  else
    printf '%s\n' "$listeners"
  fi
done

printf '%s\n' '== all non-loopback TCP listeners (audit only) =='
$SS_BIN -H -lnt 2>/dev/null \
  | awk '$4 !~ /^(127\.0\.0\.1|\[::1\]):/ { print }' \
  || true

printf '%s\n' '== Tailscale Serve =='
if serve_json=$($TAILSCALE_BIN serve status --json 2>/dev/null); then
  actual_services=$(printf '%s' "$serve_json" | $JQ_BIN -r '.Services // {} | keys[]' | sort)
  read -r -a expected_service_names <<< "${HOMELAB_TAILSCALE_SERVICES:-}"
  expected_services=$(printf '%s\n' "${expected_service_names[@]}" | awk 'NF' | sort)
  printf 'named services:\n%s\n' "$actual_services"
  if [[ $actual_services != "$expected_services" ]]; then
    fail "Tailscale named-service inventory differs from the declaration"
    printf 'expected:\n%s\n' "$expected_services" >&2
  fi
  machine_handlers=$(printf '%s' "$serve_json" | $JQ_BIN -c '{TCP: (.TCP // {}), Web: (.Web // {})}')
  printf 'machine-level handlers (reported separately): %s\n' "$machine_handlers"
else
  fail "cannot read Tailscale Serve status"
fi

printf '%s\n' '== Cloudflare tunnel =='
if ! $SYSTEMCTL_BIN is-active --quiet "${HOMELAB_CLOUDFLARED_UNIT:-cloudflared.service}" 2>/dev/null; then
  fail "Cloudflare tunnel unit is not active"
fi

printf '%s\n' '== Prometheus targets =='
if targets=$($CURL_BIN --fail --silent --show-error "${HOMELAB_PROMETHEUS_URL:-http://127.0.0.1:9090}/api/v1/targets" 2>/dev/null); then
  unhealthy=$(printf '%s' "$targets" | $JQ_BIN -r '.data.activeTargets[]? | select(.health != "up") | [.labels.job, .scrapeUrl, .lastError] | @tsv')
  if [[ -n $unhealthy ]]; then
    fail "one or more Prometheus targets are unhealthy"
    printf '%s\n' "$unhealthy" >&2
  fi
else
  fail "cannot query Prometheus targets"
fi

metric_age() {
  local metric=$1 max_age=$2 file=$3 now value age
  now=$(date +%s)
  value=$(awk -v metric="$metric" '$1 == metric { value = $2 } END { print value }' "$file" 2>/dev/null)
  if [[ -z $value ]]; then
    fail "$metric has no recorded value"
    return
  fi
  age=$((now - value))
  printf '%s age: %ss\n' "$metric" "$age"
  if (( age > max_age )); then
    fail "$metric is stale (${age}s > ${max_age}s)"
  fi
}

printf '%s\n' '== backup freshness =='
metrics_dir=${HOMELAB_METRICS_DIR:-/var/lib/prometheus-node-exporter-text-files}
metric_age homelab_backup_last_success_timestamp_seconds 129600 "$metrics_dir/homelab-backup.prom"
metric_age homelab_borg_check_last_success_timestamp_seconds 777600 "$metrics_dir/homelab-borg-check.prom"

if [[ ${HOMELAB_CHECK_ARCHIVE:-0} == 1 && $($ID_BIN -u) -eq 0 && -n ${HOMELAB_INSPECT_BIN:-} ]]; then
  printf '%s\n' '== latest archive members =='
  if latest_archive=$($HOMELAB_INSPECT_BIN 2>/dev/null | awk 'NF { name = $1 } END { print name }') && [[ -n $latest_archive ]]; then
    $HOMELAB_INSPECT_BIN "$latest_archive" || failures=$((failures + 1))
  else
    fail "cannot identify the latest Borg archive"
  fi
elif [[ -n ${HOMELAB_INSPECT_BIN:-} ]]; then
  printf '%s\n' 'INFO: latest archive inspection skipped; HOMELAB_CHECK_ARCHIVE=1 as root may attach the backup automount'
fi

if (( failures != 0 )); then
  printf 'homelab check completed with %d failure(s)\n' "$failures" >&2
  exit 1
fi

echo "homelab check passed"
