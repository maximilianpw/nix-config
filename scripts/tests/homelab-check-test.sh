#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
check_script="$repo_root/scripts/homelab-check.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/findmnt" <<'EOF'
#!/usr/bin/env bash
if [[ $3 == /mnt/backups ]]; then
  printf 'systemd-1 autofs %s\n' "$3"
else
  printf '/dev/test ext4 %s\n' "$3"
fi
EOF
cat > "$tmp/systemctl" <<'EOF'
#!/usr/bin/env bash
if [[ $1 == is-failed ]]; then exit 1; fi
if [[ $1 == is-active ]]; then exit 0; fi
if [[ $1 == --failed ]]; then exit 0; fi
exit 2
EOF
cat > "$tmp/ss" <<'EOF'
#!/usr/bin/env bash
if [[ $* == *"sport = :"* ]]; then
  port=${@: -1}
  port=${port##*:}
  if [[ $port == 8096 ]]; then
    printf 'LISTEN 0 128 0.0.0.0:%s 0.0.0.0:*\n' "$port"
  else
    printf 'LISTEN 0 128 127.0.0.1:%s 0.0.0.0:*\n' "$port"
  fi
fi
EOF
cat > "$tmp/tailscale" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"Services":{"svc:grafana":{},"svc:kuma":{}},"TCP":{},"Web":{}}'
EOF
cat > "$tmp/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"data":{"activeTargets":[{"health":"up","labels":{"job":"node"}}]}}'
EOF
cat > "$tmp/inspect" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$INSPECT_LOG"
if [[ $# == 0 ]]; then
  printf '%s\n' 'fixture-archive'
else
  printf '%s\n' 'Archive inspection passed; no files were restored'
fi
EOF
cat > "$tmp/id" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 0
EOF
chmod +x "$tmp/findmnt" "$tmp/systemctl" "$tmp/ss" "$tmp/tailscale" "$tmp/curl" "$tmp/inspect" "$tmp/id"

now=$(date +%s)
printf 'homelab_backup_last_success_timestamp_seconds %s\n' "$now" > "$tmp/homelab-backup.prom"
printf 'homelab_borg_check_last_success_timestamp_seconds %s\n' "$now" > "$tmp/homelab-borg-check.prom"

export FINDMNT_BIN=$tmp/findmnt
export SYSTEMCTL_BIN=$tmp/systemctl
export SS_BIN=$tmp/ss
export TAILSCALE_BIN=$tmp/tailscale
export CURL_BIN=$tmp/curl
export JQ_BIN
JQ_BIN=$(command -v jq)
export HOMELAB_REQUIRED_MOUNTS='/ /srv /mnt/backups'
export HOMELAB_OPTIONAL_AUTOMOUNTS='/mnt/backups'
export HOMELAB_IMPORTANT_UNITS='grafana.service borgbackup-job-main.service'
export HOMELAB_LOOPBACK_PORTS='19001 19004'
export HOMELAB_HOST_PORTS='8096'
export HOMELAB_TAILSCALE_SERVICES='svc:grafana svc:kuma'
export HOMELAB_METRICS_DIR=$tmp
export HOMELAB_INSPECT_BIN=$tmp/inspect
export ID_BIN=$tmp/id
export INSPECT_LOG=$tmp/inspect.log
: > "$INSPECT_LOG"

bash "$check_script" > "$tmp/pass.out"
grep -Fq 'homelab check passed' "$tmp/pass.out"
grep -Fq 'INFO: /mnt/backups is armed but not mounted; no access was triggered' "$tmp/pass.out"
grep -Fq 'INFO: latest archive inspection skipped' "$tmp/pass.out"
[[ ! -s $INSPECT_LOG ]]

if HOMELAB_LOOPBACK_PORTS='19001 19004 8096' HOMELAB_HOST_PORTS='' \
  bash "$check_script" > "$tmp/host-as-loopback.out" 2> "$tmp/host-as-loopback.err"; then
  echo "listener audit accepted a host-bound listener as loopback-only" >&2
  exit 1
fi
grep -Fq 'declared port 8096 has a non-loopback listener' "$tmp/host-as-loopback.err"

if HOMELAB_LOOPBACK_PORTS='19004' HOMELAB_HOST_PORTS='19001 8096' \
  bash "$check_script" > "$tmp/loopback-as-host.out" 2> "$tmp/loopback-as-host.err"; then
  echo "listener audit accepted a loopback-only listener as host-bound" >&2
  exit 1
fi
grep -Fq 'declared host-bound port 19001 has no non-loopback listener' "$tmp/loopback-as-host.err"

HOMELAB_CHECK_ARCHIVE=1 bash "$check_script" > "$tmp/archive.out"
grep -Fq 'Archive inspection passed; no files were restored' "$tmp/archive.out"
grep -Fxq '' "$INSPECT_LOG"
grep -Fxq 'fixture-archive' "$INSPECT_LOG"

printf 'homelab_backup_last_success_timestamp_seconds 1\n' > "$tmp/homelab-backup.prom"
if bash "$check_script" > "$tmp/stale.out" 2> "$tmp/stale.err"; then
  echo "stale backup metric unexpectedly passed" >&2
  exit 1
fi
grep -Fq 'homelab_backup_last_success_timestamp_seconds is stale' "$tmp/stale.err"

echo "homelab check tests passed"
