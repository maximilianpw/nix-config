#!/usr/bin/env bash

set -euo pipefail

: "${DOCKER_BIN:=docker}"
: "${DATE_BIN:=date}"
: "${JQ_BIN:=jq}"
: "${HOMELAB_METRICS_DIR:=/var/lib/prometheus-node-exporter-text-files}"
: "${HOMELAB_CONTAINER_STALE_AFTER_SECONDS:=259200}"

if [[ ! $HOMELAB_CONTAINER_STALE_AFTER_SECONDS =~ ^[0-9]+$ ]] ||
  ((HOMELAB_CONTAINER_STALE_AFTER_SECONDS == 0)); then
  echo "HOMELAB_CONTAINER_STALE_AFTER_SECONDS must be a positive integer" >&2
  exit 2
fi

now_epoch=${NOW_EPOCH:-$($DATE_BIN +%s)}
if [[ ! $now_epoch =~ ^[0-9]+$ ]]; then
  echo "NOW_EPOCH must be a non-negative integer" >&2
  exit 2
fi

metrics_file="$HOMELAB_METRICS_DIR/homelab-docker-containers.prom"
metrics_tmp="$(mktemp "${metrics_file}.XXXXXX")"
inspect_tmp="$(mktemp)"
stats_tmp="$(mktemp)"
field_separator=$'\x1f'

cleanup() {
  rm -f "$metrics_tmp" "$inspect_tmp" "$stats_tmp"
}
trap cleanup EXIT

prometheus_escape() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  printf '%s' "$value"
}

container_id_output=$("$DOCKER_BIN" ps --quiet)
container_ids=()
if [[ -n $container_id_output ]]; then
  mapfile -t container_ids <<< "$container_id_output"
fi

if ((${#container_ids[@]} > 0)); then
  "$DOCKER_BIN" inspect "${container_ids[@]}" | "$JQ_BIN" -r '
    .[]
    | [
        (.Name // ""),
        (.Created // ""),
        (.HostConfig.RestartPolicy.Name // ""),
        (.Config.Labels["com.docker.compose.project"] // ""),
        (.Config.Labels["com.docker.compose.project.working_dir"] // ""),
        (.Config.Labels["homelab.ephemeral"] // ""),
        (.Config.Labels["homelab.keep"] // ""),
        ((.State.Health.Status // "none") | ascii_downcase),
        ((.NetworkSettings.Ports // {}) | tojson)
      ]
    | join("\u001f")
  ' > "$inspect_tmp"
  "$DOCKER_BIN" stats --no-stream \
    --format '{{json .}}' \
    "${container_ids[@]}" | "$JQ_BIN" -Rr '
      fromjson
      | [(.Name // ""), (.CPUPerc // ""), (.MemUsage // ""), (.BlockIO // "")]
      | join("\u001f")
    ' > "$stats_tmp"
fi

container_count=0
stale_count=0
unhealthy_count=0

{
  printf '# HELP homelab_docker_containers Number of running Docker containers.\n'
  printf '# TYPE homelab_docker_containers gauge\n'
  printf '# HELP homelab_docker_stale_containers Number of running Docker containers older than the audit threshold.\n'
  printf '# TYPE homelab_docker_stale_containers gauge\n'
  printf '# HELP homelab_docker_container_age_seconds Age of a running Docker container.\n'
  printf '# TYPE homelab_docker_container_age_seconds gauge\n'
  printf '# HELP homelab_docker_stale_container_info Metadata for a stale running Docker container.\n'
  printf '# TYPE homelab_docker_stale_container_info gauge\n'
  printf '# HELP homelab_docker_unhealthy_containers Number of running Docker containers reporting unhealthy.\n'
  printf '# TYPE homelab_docker_unhealthy_containers gauge\n'
  printf '# HELP homelab_docker_container_health Container health state as reported by Docker.\n'
  printf '# TYPE homelab_docker_container_health gauge\n'

  while IFS=$field_separator read -r raw_name created restart_policy project working_dir ephemeral keep health ports; do
    [[ -n $raw_name ]] || continue
    name=${raw_name#/}
    for variable in project working_dir ephemeral keep; do
      if [[ ${!variable} == '<no value>' || ${!variable} == '<nil>' ]]; then
        printf -v "$variable" '%s' ''
      fi
    done
    [[ $ephemeral == true ]] || ephemeral=false
    [[ $keep == true ]] || keep=false
    [[ -n $project ]] || project=unmanaged
    [[ -n $restart_policy ]] || restart_policy=none
    case $health in
      healthy | unhealthy | starting | none) ;;
      *) health=unknown ;;
    esac

    created_epoch=$($DATE_BIN --date="$created" +%s)
    if [[ ! $created_epoch =~ ^[0-9]+$ ]] || ((created_epoch > now_epoch)); then
      echo "Cannot calculate a valid age for Docker container $name" >&2
      exit 1
    fi
    age_seconds=$((now_epoch - created_epoch))
    container_count=$((container_count + 1))

    stats=$(awk -F "$field_separator" -v name="$name" -v separator="$field_separator" \
      '$1 == name { print $2 separator $3 separator $4; exit }' "$stats_tmp")
    IFS=$field_separator read -r cpu_usage memory_usage block_io <<< "$stats"
    printf 'container=%q project=%q age=%ss health=%q cpu=%q memory=%q block_io=%q restart=%q ephemeral=%s keep=%s working_dir=%q ports=%q\n' \
      "$name" "$project" "$age_seconds" "$health" "${cpu_usage:-unknown}" "${memory_usage:-unknown}" \
      "${block_io:-unknown}" "$restart_policy" "$ephemeral" "$keep" "${working_dir:-unknown}" "${ports:-unknown}" >&2

    escaped_name=$(prometheus_escape "$name")
    escaped_project=$(prometheus_escape "$project")
    printf 'homelab_docker_container_age_seconds{name="%s",project="%s",ephemeral="%s",keep="%s"} %s\n' \
      "$escaped_name" "$escaped_project" "$ephemeral" "$keep" "$age_seconds"
    printf 'homelab_docker_container_health{name="%s",project="%s",status="%s"} 1\n' \
      "$escaped_name" "$escaped_project" "$health"
    if [[ $health == unhealthy ]]; then
      unhealthy_count=$((unhealthy_count + 1))
    fi

    if ((age_seconds >= HOMELAB_CONTAINER_STALE_AFTER_SECONDS)) && [[ $keep != true ]]; then
      stale_count=$((stale_count + 1))
      printf 'homelab_docker_stale_container_info{name="%s",project="%s",ephemeral="%s"} 1\n' \
        "$escaped_name" "$escaped_project" "$ephemeral"
    fi
  done < "$inspect_tmp"

  printf 'homelab_docker_containers %s\n' "$container_count"
  printf 'homelab_docker_stale_containers %s\n' "$stale_count"
  printf 'homelab_docker_unhealthy_containers %s\n' "$unhealthy_count"
} > "$metrics_tmp"

chmod 0644 "$metrics_tmp"
mv -f "$metrics_tmp" "$metrics_file"
trap - EXIT
rm -f "$inspect_tmp" "$stats_tmp"

printf 'Docker container audit complete: %s running, %s stale, %s unhealthy\n' \
  "$container_count" "$stale_count" "$unhealthy_count"
