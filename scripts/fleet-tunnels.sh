#!/usr/bin/env bash
# Rendered into the fleet CLI. Not executed as a standalone script.

tunnel_uid() {
  id -u
}

tunnel_target() {
  printf 'gui/%s/%s\n' "$(tunnel_uid)" "$1"
}

tunnel_plist_path() {
  printf '%s/Library/LaunchAgents/%s.plist\n' "${HOME:?HOME is required for launchd tunnels}" "$1"
}

validate_remote_host() {
  case "$1" in
    "" | *[!A-Za-z0-9._-]*)
      echo "fleet: invalid remote tunnel host: $1" >&2
      exit 2
      ;;
  esac
}

tcp_probe() {
  host="$1"
  port="$2"
  if [ -n "${FLEET_TCP_PROBE:-}" ]; then
    "$FLEET_TCP_PROBE" "$host" "$port"
    return
  fi
  # Positional arguments expand in the timeout-bounded child shell.
  # shellcheck disable=SC2016
  timeout --kill-after=1s 3s bash -c 'exec 3<>"/dev/tcp/$1/$2"' bash "$host" "$port" >/dev/null 2>&1
}

require_launchd_supervisor() {
  if [ "$(tunnel_supervisor)" != launchd ]; then
    echo "fleet: managed tunnels are supervised by macOS launchd; this host has no tunnel supervisor." >&2
    exit 2
  fi
}

require_launchctl() {
  if ! command -v launchctl >/dev/null 2>&1; then
    echo "fleet: launchctl is required to manage Darwin tunnel jobs" >&2
    exit 1
  fi
}

lookup_tunnel() {
  want="$1"
  while IFS='|' read -r local_port host remote_port remote_host label; do
    [ -n "${local_port:-}" ] || continue
    case "$local_port" in
      \#*) continue ;;
    esac
    if [ "$local_port" = "$want" ]; then
      printf '%s|%s|%s|%s|%s\n' "$local_port" "$host" "$remote_port" "$remote_host" "$label"
      return 0
    fi
  done <<EOF
$(list_tunnel_mappings)
EOF
  return 1
}

tunnels_for_host() {
  want="$1"
  while IFS='|' read -r local_port host remote_port remote_host label; do
    [ -n "${local_port:-}" ] || continue
    case "$local_port" in
      \#*) continue ;;
    esac
    if [ "$(canonical_fleet_host "$host")" = "$want" ]; then
      printf '%s|%s|%s|%s|%s\n' "$local_port" "$want" "$remote_port" "$remote_host" "$label"
    fi
  done <<EOF
$(list_tunnel_mappings)
EOF
}

has_managed_tunnels() {
  while IFS='|' read -r local_port _rest; do
    [ -n "${local_port:-}" ] || continue
    case "$local_port" in
      \#*) continue ;;
    esac
    return 0
  done <<EOF
$(list_tunnel_mappings)
EOF
  return 1
}

launchctl_print() {
  launchctl print "$1" 2>/dev/null
}

tunnel_is_disabled() {
  label="$1"
  # launchctl print-disabled is the persistent override; do not infer pause
  # from a missing job, which would confuse logout with an explicit pause.
  disabled_out="$(launchctl print-disabled "gui/$(tunnel_uid)" 2>/dev/null || true)"
  line="$(printf '%s\n' "$disabled_out" | grep -F "\"$label\"" | head -n 1 || true)"
  if [ -z "$line" ]; then
    return 1
  fi
  case "$line" in
    *false* | *enabled*)
      return 1
      ;;
    *true* | *disabled*)
      return 0
      ;;
  esac
  return 1
}

tunnel_is_loaded() {
  launchctl_print "$(tunnel_target "$1")" >/dev/null
}

tunnel_is_running() {
  label="$1"
  print_out="$(launchctl_print "$(tunnel_target "$label")" || true)"
  [ -n "$print_out" ] || return 1
  printf '%s\n' "$print_out" | grep -Eq 'state[[:space:]]*=[[:space:]]*running'
}

tunnel_pid() {
  local key equals value rest
  while read -r key equals value rest; do
    if [ "$key" = pid ] && [ "$equals" = = ]; then
      case "$value" in
        ""|*[!0-9]*) return 1 ;;
        *) printf '%s\n' "$value"; return 0 ;;
      esac
    fi
  done <<EOF
$(launchctl_print "$(tunnel_target "$1")" || true)
EOF
  return 1
}

classify_local_listen() {
  local port="$1" label="$2" listeners pid listener parent command
  # A running job might still be authenticating while another process owns the
  # port. Match launchd's process or the runner's direct SSH child, not merely
  # the fact that some process is listening.
  listeners="$(timeout --kill-after=1s 3s lsof -nP -a -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null || true)"
  if [ -z "$listeners" ]; then
    if tcp_probe 127.0.0.1 "$port"; then
      printf '%s\n' unrelated
    else
      printf '%s\n' none
    fi
    return
  fi
  pid="$(tunnel_pid "$label" || true)"
  while IFS= read -r listener; do
    if [ "$listener" != "$pid" ]; then
      parent=
      command=
      read -r parent command < <(ps -p "$listener" -o ppid=,comm= 2>/dev/null) || true
      if [ -z "$pid" ] || [ "$parent" != "$pid" ] || [ "${command##*/}" != ssh ]; then
        printf '%s\n' unrelated
        return
      fi
    fi
  done <<EOF
$listeners
EOF
  printf '%s\n' owned
}

supervisor_state() {
  label="$1"
  if [ "$(tunnel_supervisor)" != launchd ]; then
    printf '%s\n' none
    return
  fi
  if tunnel_is_disabled "$label"; then
    printf '%s\n' paused
    return
  fi
  if tunnel_is_running "$label"; then
    printf '%s\n' running
    return
  fi
  printf '%s\n' stopped
}

print_tunnel_status_table() {
  printf '%-8s %-28s %-12s %-10s %s\n' LOCAL REMOTE SUPERVISOR STATE LOCAL_LISTEN
  found=0
  while IFS='|' read -r local_port host remote_port remote_host label; do
    [ -n "${local_port:-}" ] || continue
    case "$local_port" in
      \#*) continue ;;
    esac
    found=1
    if [ "$(tunnel_supervisor)" = launchd ]; then
      require_launchctl
      state="$(supervisor_state "$label")"
      listen="$(classify_local_listen "$local_port" "$label")"
    else
      state=unsupervised
      listen="$(classify_local_listen "$local_port" "$label")"
    fi
    printf '%-8s %-28s %-12s %-10s %s\n' \
      "$local_port" \
      "${host}:${remote_host}:${remote_port}" \
      "$(tunnel_supervisor)" \
      "$state" \
      "$listen"
  done <<EOF
$(list_tunnel_mappings)
EOF

  if [ "$found" -eq 0 ]; then
    printf '%s\n' 'No managed tunnels configured on this host.'
  elif [ "$(tunnel_supervisor)" != launchd ]; then
    printf '%s\n' 'Managed tunnel jobs are installed only on macOS (launchd).'
  fi
}

tunnel_status() {
  if [ "$(tunnel_supervisor)" = launchd ]; then
    require_launchctl
  fi
  print_tunnel_status_table
}

tunnel_pause() {
  if [ "$#" -ne 1 ]; then
    echo "fleet: pause requires a local port" >&2
    exit 2
  fi
  require_launchd_supervisor
  require_launchctl
  validate_port "$1"
  row="$(lookup_tunnel "$1" || true)"
  if [ -z "$row" ]; then
    echo "fleet: no managed tunnel for local port $1" >&2
    exit 2
  fi
  IFS='|' read -r local_port _host _remote_port _remote_host label <<EOF
$row
EOF
  target="$(tunnel_target "$label")"
  if ! launchctl disable "$target"; then
    echo "fleet: failed to persist pause for $target" >&2
    exit 1
  fi
  if tunnel_is_loaded "$label"; then
    if ! launchctl bootout --wait "$target"; then
      echo "fleet: failed to stop managed tunnel job $target" >&2
      exit 1
    fi
  fi
  printf 'fleet: paused managed tunnel for local port %s\n' "$local_port"
}

tunnel_resume() {
  if [ "$#" -ne 1 ]; then
    echo "fleet: resume requires a local port" >&2
    exit 2
  fi
  require_launchd_supervisor
  require_launchctl
  validate_port "$1"
  row="$(lookup_tunnel "$1" || true)"
  if [ -z "$row" ]; then
    echo "fleet: no managed tunnel for local port $1" >&2
    exit 2
  fi
  IFS='|' read -r local_port _host _remote_port _remote_host label <<EOF
$row
EOF
  target="$(tunnel_target "$label")"
  plist="$(tunnel_plist_path "$label")"
  disabled=no
  running=no
  if tunnel_is_disabled "$label"; then
    disabled=yes
  fi
  if tunnel_is_running "$label"; then
    running=yes
  fi
  listen="$(classify_local_listen "$local_port" "$label")"

  if [ "$running" = yes ] && [ "$disabled" = no ] && [ "$listen" = owned ]; then
    printf 'fleet: managed tunnel for local port %s is already running\n' "$local_port"
    return 0
  fi

  if [ "$listen" = unrelated ]; then
    printf 'fleet: local port %s is occupied by an unrelated process; not killing it.\n' "$local_port" >&2
    printf 'fleet: stop that listener, then retry resume. Pause remains in effect.\n' >&2
    exit 1
  fi

  if [ ! -f "$plist" ]; then
    echo "fleet: launchd plist missing: $plist (re-apply Home Manager on this Mac)" >&2
    exit 1
  fi

  if ! launchctl enable "$target"; then
    echo "fleet: failed to clear pause for $target" >&2
    exit 1
  fi
  if ! tunnel_is_loaded "$label"; then
    if ! launchctl bootstrap "gui/$(tunnel_uid)" "$plist"; then
      echo "fleet: failed to load managed tunnel job $target" >&2
      exit 1
    fi
  fi
  if ! tunnel_is_running "$label"; then
    if ! launchctl kickstart "$target"; then
      echo "fleet: failed to start managed tunnel job $target" >&2
      exit 1
    fi
  fi
  printf 'fleet: resumed managed tunnel for local port %s\n' "$local_port"
}

classify_ssh_failure() {
  stderr_file="$1"
  stderr="$(cat "$stderr_file" 2>/dev/null || true)"
  case "$stderr" in
    *"Permission denied"* | *"publickey"* | *"Too many authentication"* | *"Host key verification failed"* | *"No more authentication methods"*)
      printf '%s\n' auth
      ;;
    *"Connection refused"* | *"Connection timed out"* | *"Operation timed out"* | *"Network is unreachable"* | *"No route to host"* | *"Could not resolve"* | *"Name or service not known"* | *"Temporary failure in name resolution"*)
      printf '%s\n' unavailable
      ;;
    *)
      printf '%s\n' unavailable
      ;;
  esac
}

doctor_ssh() {
  local host="$1" stderr_file="$2"
  timeout --kill-after=2s 15s ssh -n \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -o ControlMaster=no \
    -o ControlPath=none \
    -o ForwardAgent=no \
    "$host" : 2>"$stderr_file"
}

doctor_remote_listen() {
  local host="$1" remote_host="$2" remote_port="$3"
  validate_remote_host "$remote_host"
  validate_port "$remote_port"
  # Do not let SSH consume the mapping loop's input and skip later ports.
  timeout --kill-after=2s 15s ssh -n \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -o ControlMaster=no \
    -o ControlPath=none \
    -o ForwardAgent=no \
    "$host" \
    "bash -c 'command -v timeout >/dev/null || exit 69; if timeout 3 bash -c \"exec 3<>/dev/tcp/${remote_host}/${remote_port}\"; then exit 0; else exit 1; fi'"
}

fleet_doctor() {
  if [ "$#" -ne 1 ]; then
    echo "fleet: doctor requires a host" >&2
    exit 2
  fi
  host="$(canonical_fleet_host "$1")" || exit 2
  unhealthy=0
  ssh_state=skipped
  stderr_file="$(mktemp "${TMPDIR:-/tmp}/fleet-doctor.XXXXXX")"
  trap 'rm -f -- "$stderr_file"' EXIT

  if is_local_host "$host"; then
    ssh_state=skipped
    printf '%s\n' 'SSH: skipped (current machine)'
  else
    if doctor_ssh "$host" "$stderr_file"; then
      ssh_state=reachable
      printf '%s\n' 'SSH: reachable'
    else
      ssh_state="$(classify_ssh_failure "$stderr_file")"
      if [ "$ssh_state" = auth ]; then
        printf '%s\n' 'SSH: auth failure'
        printf 'unhealthy: SSH to %s failed authentication\n' "$host"
      else
        ssh_state=unavailable
        printf '%s\n' 'SSH: unavailable'
        printf 'unhealthy: SSH to %s is unavailable\n' "$host"
      fi
      unhealthy=1
    fi
  fi

  if [ "$(tunnel_supervisor)" = launchd ]; then
    require_launchctl
  fi

  found=0
  while IFS='|' read -r local_port mapping_host remote_port remote_host label; do
    [ -n "${local_port:-}" ] || continue
    case "$local_port" in
      \#*) continue ;;
    esac
    [ "$mapping_host" = "$host" ] || continue
    found=1
    if [ "$(tunnel_supervisor)" = launchd ]; then
      state="$(supervisor_state "$label")"
    else
      state=unsupervised
    fi
    listen="$(classify_local_listen "$local_port" "$label")"

    remote=skipped
    if [ "$ssh_state" = reachable ] && [ "$state" != paused ]; then
      if doctor_remote_listen "$host" "$remote_host" "$remote_port" 2>"$stderr_file"; then
        remote=listening
      else
        probe_status=$?
        if [ "$probe_status" -eq 1 ]; then
          remote=down
        else
          remote=unknown
          printf 'unhealthy: remote TCP probe failed for %s (SSH/probe exit %s); app state unknown\n' "$host" "$probe_status"
          unhealthy=1
        fi
      fi
    fi

    printf 'tunnel %s: supervisor=%s local=%s remote=%s\n' "$local_port" "$state" "$listen" "$remote"

    if [ "$state" = paused ]; then
      continue
    fi
    if [ "$state" = unsupervised ]; then
      printf 'unhealthy: managed tunnel for local port %s is not supervised on this host\n' "$local_port"
      unhealthy=1
      continue
    fi
    if [ "$state" != running ]; then
      printf 'unhealthy: managed tunnel for local port %s is not running\n' "$local_port"
      unhealthy=1
    fi
    if [ "$listen" = unrelated ]; then
      printf 'unhealthy: local port %s is occupied by an unrelated process\n' "$local_port"
      unhealthy=1
    elif [ "$listen" = none ] && [ "$state" = running ]; then
      printf 'unhealthy: managed tunnel for local port %s is not listening on 127.0.0.1\n' "$local_port"
      unhealthy=1
    fi
    if [ "$remote" = down ]; then
      printf 'unhealthy: remote app is not listening on %s %s:%s\n' "$host" "$remote_host" "$remote_port"
      unhealthy=1
    fi
  done <<EOF
$(tunnels_for_host "$host")
EOF

  if [ "$found" -eq 0 ]; then
    if has_managed_tunnels; then
      printf '%s\n' "No managed tunnels target $host."
    else
      printf '%s\n' 'No managed tunnels configured on this host.'
    fi
  fi

  if [ "$unhealthy" -ne 0 ]; then
    exit 1
  fi
}
