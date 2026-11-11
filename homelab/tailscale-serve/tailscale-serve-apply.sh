#!/usr/bin/env bash
set -eu

expected_domain=@EXPECTED_DOMAIN@

is_desired_service() {
  case "$1" in
    @DESIRED_SERVICE_PATTERN@) return 0 ;;
    *) return 1 ;;
  esac
}

apply_config() {
  current_status="$(@TAILSCALE_BIN@ serve status --json)" || return 1
  current_services="$(printf '%s\n' "$current_status" | @JQ_BIN@ -r '.Services // {} | keys[]')" || return 1
  while IFS= read -r service; do
    [[ -n $service ]] || continue
    @TAILSCALE_BIN@ serve drain "$service" || return 1
    if ! is_desired_service "$service"; then
      @TAILSCALE_BIN@ serve clear "$service" || return 1
    fi
  done <<< "$current_services"

  stale_services="$(printf '%s\n' "$current_status" | @JQ_BIN@ -r --arg suffix ".$expected_domain:443" '[.Services // {} | to_entries[] | .key as $service | (.value.Web // {} | keys[]) | select(endswith($suffix) | not) | $service] | unique[]')" || return 1
  while IFS= read -r service; do
    [[ -n $service ]] || continue
    is_desired_service "$service" || continue
    @TAILSCALE_BIN@ serve clear "$service" || return 1
  done <<< "$stale_services"

  @APPLY_COMMANDS@

  current_hosts="$(@TAILSCALE_BIN@ serve status --json | @JQ_BIN@ -r '.Services // {} | .[] | .Web // {} | keys[]')" || return 1
  while IFS= read -r host; do
    [[ -n $host ]] || continue
    case "$host" in
      *."$expected_domain":443) ;;
      *)
        echo "Tailscale Serve still advertises stale host $host; expected *.$expected_domain:443" >&2
        return 1
        ;;
    esac
  done <<< "$current_hosts"
}

attempt=1
delay=2
while [[ $attempt -le 8 ]]; do
  if apply_config; then
    exit 0
  fi

  if [[ $attempt -eq 8 ]]; then
    break
  fi

  echo "failed to apply Tailscale Serve configuration (attempt $attempt/8); retrying in ${delay}s" >&2
  @SLEEP_BIN@ "$delay"
  attempt=$((attempt + 1))
  if [[ $delay -lt 30 ]]; then
    delay=$((delay * 2))
  fi
done

echo "failed to apply Tailscale Serve configuration after 8 attempts" >&2
exit 1
