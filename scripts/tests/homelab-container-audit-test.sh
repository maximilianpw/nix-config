#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

metrics_dir="$test_root/metrics"
fake_docker="$test_root/docker"
mkdir -p "$metrics_dir"

cat > "$fake_docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ ${FAIL_DOCKER:-0} == 1 ]]; then
  exit 1
fi

case ${1:-} in
  ps)
    [[ ${FAKE_EMPTY:-0} == 1 ]] || printf 'old\nkept\nnew\n'
    ;;
  inspect)
    cat <<'INSPECT'
[
  {"Name":"/old-dev","Created":"1970-01-01T00:16:40Z","State":{"Health":{"Status":"unhealthy"}},"HostConfig":{"RestartPolicy":{"Name":"no"}},"Config":{"Labels":{"com.docker.compose.project":"stocket-dev","com.docker.compose.project.working_dir":"/home/maxpw/stocket","homelab.ephemeral":"true","homelab.keep":"false"}},"NetworkSettings":{"Ports":{"5432/tcp":[{"HostIp":"127.0.0.1","HostPort":"5432"}]}}},
  {"Name":"/kept-prod","Created":"1970-01-01T00:16:40Z","State":{"Health":{"Status":"healthy"}},"HostConfig":{"RestartPolicy":{"Name":"always"}},"Config":{"Labels":{"com.docker.compose.project":"buzz-prod","com.docker.compose.project.working_dir":"/nix/store/example","homelab.ephemeral":"false","homelab.keep":"true"}},"NetworkSettings":{"Ports":{}}},
  {"Name":"/new-unmanaged","Created":"1970-01-05T12:20:00Z","State":{},"HostConfig":{"RestartPolicy":{"Name":"no"}},"Config":{"Labels":{}},"NetworkSettings":{"Ports":{}}}
]
INSPECT
    ;;
  stats)
    cat <<'STATS'
{"Name":"old-dev","CPUPerc":"2.00%","MemUsage":"10MiB / 1GiB","BlockIO":"1MB / 2MB"}
{"Name":"kept-prod","CPUPerc":"1.00%","MemUsage":"20MiB / 1GiB","BlockIO":"3MB / 4MB"}
{"Name":"new-unmanaged","CPUPerc":"0.00%","MemUsage":"5MiB / 1GiB","BlockIO":"0B / 0B"}
STATS
    ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$fake_docker"

DOCKER_BIN="$fake_docker" \
  HOMELAB_METRICS_DIR="$metrics_dir" \
  HOMELAB_CONTAINER_STALE_AFTER_SECONDS=86400 \
  NOW_EPOCH=400000 \
  "$script_dir/homelab-container-audit.sh" >/dev/null

metrics_file="$metrics_dir/homelab-docker-containers.prom"
grep -F 'homelab_docker_containers 3' "$metrics_file"
grep -F 'homelab_docker_stale_containers 1' "$metrics_file"
grep -F 'homelab_docker_unhealthy_containers 1' "$metrics_file"
grep -F 'homelab_docker_container_health{name="old-dev",project="stocket-dev",status="unhealthy"} 1' "$metrics_file"
grep -F 'homelab_docker_container_health{name="new-unmanaged",project="unmanaged",status="none"} 1' "$metrics_file"
grep -F 'homelab_docker_stale_container_info{name="old-dev",project="stocket-dev",ephemeral="true"} 1' "$metrics_file"
grep -F 'homelab_docker_container_age_seconds{name="new-unmanaged",project="unmanaged",ephemeral="false",keep="false"} 10000' "$metrics_file"
if grep -Fq 'name="kept-prod"' < <(grep 'homelab_docker_stale_container_info' "$metrics_file"); then
  echo "keep-labeled container was incorrectly reported as stale" >&2
  exit 1
fi
test "$(stat -c '%a' "$metrics_file")" = 644

cp "$metrics_file" "$test_root/expected.prom"
if FAIL_DOCKER=1 DOCKER_BIN="$fake_docker" HOMELAB_METRICS_DIR="$metrics_dir" \
  "$script_dir/homelab-container-audit.sh" >/dev/null 2>&1; then
  echo "container audit unexpectedly accepted a Docker failure" >&2
  exit 1
fi
cmp "$test_root/expected.prom" "$metrics_file"

FAKE_EMPTY=1 DOCKER_BIN="$fake_docker" HOMELAB_METRICS_DIR="$metrics_dir" \
  "$script_dir/homelab-container-audit.sh" >/dev/null
grep -F 'homelab_docker_containers 0' "$metrics_file"
grep -F 'homelab_docker_stale_containers 0' "$metrics_file"
grep -F 'homelab_docker_unhealthy_containers 0' "$metrics_file"

echo "homelab container audit tests passed"
