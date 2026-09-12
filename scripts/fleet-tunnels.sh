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
  local host="$1" port="$2"
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
  local want="$1" local_port host remote_port remote_host label
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
  local want="$1" local_port host remote_port remote_host label
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
  local local_port _rest
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

# Output: state|loaded|pid, with an empty PID when the job has none.
supervisor_snapshot() {
  local label="$1" state=stopped loaded=no pid=
  local job_output key equals value rest
  if [ "$(tunnel_supervisor)" != launchd ]; then
    printf '%s\n' 'unsupervised|no|'
    return
  fi

  # State and PID must come from the same job read. A restart between separate
  # reads could otherwise combine an old state with a replacement process.
  if job_output="$(launchctl_print "$(tunnel_target "$label")")"; then
    loaded=yes
  fi
  while read -r key equals value rest; do
    [ "$equals" = = ] || continue
    case "$key" in
      state) [ "$value" != running ] || state=running ;;
      pid)
        case "$value" in
          ""|*[!0-9]*) ;;
          *) pid="$value" ;;
        esac
        ;;
    esac
  done <<EOF
$job_output
EOF

  # Pause is a persistent override, independent of whether the job is loaded.
  # This is a separate launchd read, not an atomic snapshot of the whole OS.
  while read -r key equals value rest; do
    [ "$key" = "\"$label\"" ] && [ "$equals" = '=>' ] || continue
    case "$value" in
      true|disabled) state=paused ;;
    esac
    break
  done <<EOF
$(launchctl print-disabled "gui/$(tunnel_uid)" 2>/dev/null || true)
EOF
  printf '%s|%s|%s\n' "$state" "$loaded" "$pid"
}

classify_local_listen() {
  local port="$1" pid="$2" listeners listener parent command
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

# Output: supervisor state|listener ownership (owned, unrelated, or none).
inspect_tunnel() {
  local port="$1" label="$2" state _loaded pid listen
  IFS='|' read -r state _loaded pid <<EOF
$(supervisor_snapshot "$label")
EOF
  listen="$(classify_local_listen "$port" "$pid")"
  # Shared observation for status, doctor, and resume. Ownership uses the PID
  # already captured above; it must not independently query launchd again.
  printf '%s|%s\n' "$state" "$listen"
}

print_tunnel_status_table() {
  local found=0 local_port host remote_port remote_host label
  local state listen supervisor
  supervisor="$(tunnel_supervisor)"
  printf '%-8s %-28s %-12s %-10s %s\n' LOCAL REMOTE SUPERVISOR STATE LOCAL_LISTEN
  while IFS='|' read -r local_port host remote_port remote_host label; do
    [ -n "${local_port:-}" ] || continue
    case "$local_port" in
      \#*) continue ;;
    esac
    found=1
    IFS='|' read -r state listen <<EOF
$(inspect_tunnel "$local_port" "$label")
EOF
    printf '%-8s %-28s %-12s %-10s %s\n' \
      "$local_port" \
      "${host}:${remote_host}:${remote_port}" \
      "$supervisor" \
      "$state" \
      "$listen"
  done <<EOF
$(list_tunnel_mappings)
EOF

  if [ "$found" -eq 0 ]; then
    printf '%s\n' 'No managed tunnels configured on this host.'
  elif [ "$supervisor" != launchd ]; then
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
  local row local_port _host _remote_port _remote_host label target
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
  if launchctl_print "$target" >/dev/null; then
    if ! launchctl bootout --wait "$target"; then
      echo "fleet: failed to stop managed tunnel job $target" >&2
      exit 1
    fi
  fi
  printf 'fleet: paused managed tunnel for local port %s\n' "$local_port"
}

tunnel_resume() {
  local row local_port _host _remote_port _remote_host label target plist
  local state loaded listen _pid
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
  IFS='|' read -r state listen <<EOF
$(inspect_tunnel "$local_port" "$label")
EOF

  if [ "$state" = running ] && [ "$listen" = owned ]; then
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
  # Mutations invalidate the earlier observation. Refresh once after enable,
  # and again only if bootstrap may have started a new RunAtLoad process.
  IFS='|' read -r state loaded _pid <<EOF
$(supervisor_snapshot "$label")
EOF
  if [ "$loaded" = no ]; then
    if ! launchctl bootstrap "gui/$(tunnel_uid)" "$plist"; then
      echo "fleet: failed to load managed tunnel job $target" >&2
      exit 1
    fi
    IFS='|' read -r state loaded _pid <<EOF
$(supervisor_snapshot "$label")
EOF
  fi
  if [ "$state" != running ]; then
    if ! launchctl kickstart "$target"; then
      echo "fleet: failed to start managed tunnel job $target" >&2
      exit 1
    fi
  fi
  printf 'fleet: resumed managed tunnel for local port %s\n' "$local_port"
}

classify_ssh_failure() {
  local stderr_file="$1" stderr
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

fleet_doctor() (
  # A subshell scopes the temporary-file EXIT trap as well as local variables.
  local host unhealthy=0 ssh_state=skipped stderr_file found=0
  local local_port mapping_host remote_port remote_host label state listen
  local remote probe_status
  if [ "$#" -ne 1 ]; then
    echo "fleet: doctor requires a host" >&2
    exit 2
  fi
  host="$(canonical_fleet_host "$1")" || exit 2
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

  while IFS='|' read -r local_port mapping_host remote_port remote_host label; do
    [ -n "${local_port:-}" ] || continue
    case "$local_port" in
      \#*) continue ;;
    esac
    [ "$mapping_host" = "$host" ] || continue
    found=1
    IFS='|' read -r state listen <<EOF
$(inspect_tunnel "$local_port" "$label")
EOF

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
)
