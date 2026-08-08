#!/usr/bin/env bash
set -eu

is_local_host() {
  # @LOCAL_HOST_CASE@
  return 1
}

validate_session() {
  case "$1" in
    *[!A-Za-z0-9_.-]*)
      echo "fleet: session names may only contain A-Z, a-z, 0-9, _, ., and -" >&2
      exit 2
      ;;
  esac
}

validate_port() {
  case "$1" in
    ""|*[!0-9]*)
      echo "fleet: ports must be numeric" >&2
      exit 2
      ;;
  esac
}

forward_local_port() {
  spec="$1"
  first="${spec%%:*}"
  rest="${spec#*:}"
  if [ "$rest" = "$spec" ]; then
    return 1
  fi

  case "$first" in
    ""|*[!0-9]*)
      port="${rest%%:*}"
      ;;
    *)
      port="$first"
      ;;
  esac

  case "$port" in
    ""|*[!0-9]*)
      return 1
      ;;
  esac

  printf '%s\n' "$port"
}

forward_row() {
  pid="$1"
  spec="$2"
  local_port="$(forward_local_port "$spec" || true)"
  [ -n "$local_port" ] || return 0
  printf '%s|%s|%s\n' "$pid" "$local_port" "$spec"
}

collect_forward_rows() {
  if ps_output="$(ps axww -o pid=,command= 2>/dev/null)"; then
    :
  else
    ps_output="$(ps -eww -o pid=,args= 2>/dev/null || true)"
  fi

  while IFS= read -r line; do
    # Intentionally split the ps line back into argv-like fields so -L
    # and its value can be detected in both "-L spec" and "-Lspec" forms.
    # shellcheck disable=SC2086
    set -- $line
    if [ "$#" -lt 2 ]; then
      continue
    fi

    pid="$1"
    shift
    case "$pid" in
      ""|*[!0-9]*)
        continue
        ;;
    esac

    program="$1"
    shift
    case "$program" in
      ssh|*/ssh)
        ;;
      *)
        continue
        ;;
    esac

    while [ "$#" -gt 0 ]; do
      arg="$1"
      shift
      if [ "$arg" = "-L" ]; then
        if [ "$#" -gt 0 ]; then
          forward_row "$pid" "$1"
          shift
        fi
        continue
      fi

      case "$arg" in
        -L?*)
          forward_row "$pid" "${arg#-L}"
          ;;
      esac
    done
  done <<EOF
$ps_output
EOF
}

list_forwards() {
  filter_port="${1:-}"
  rows="$(collect_forward_rows)"
  found=0

  if [ -n "$filter_port" ]; then
    validate_port "$filter_port"
    printf 'Active SSH local forwards for port %s:\n' "$filter_port"
  else
    printf '%s\n' 'Active SSH local forwards:'
  fi
  printf '%-8s %-10s %-36s %s\n' PID LOCAL_PORT FORWARD DELETE_COMMAND

  while IFS='|' read -r pid local_port spec; do
    [ -n "$pid" ] || continue
    if [ -n "$filter_port" ] && [ "$local_port" != "$filter_port" ]; then
      continue
    fi

    found=1
    printf '%-8s %-10s %-36s %s\n' "$pid" "$local_port" "$spec" "fleet forward delete $pid"
  done <<EOF
$rows
EOF

  if [ "$found" -eq 0 ]; then
    if [ -n "$filter_port" ]; then
      printf 'No active SSH local forwards found for local port %s.\n' "$filter_port"
    else
      printf '%s\n' 'No active SSH local forwards found.'
    fi
  fi
}

port_has_forward() {
  filter_port="$1"
  rows="$(collect_forward_rows)"

  while IFS='|' read -r pid local_port spec; do
    [ -n "$pid" ] || continue
    [ -n "$spec" ] || continue
    if [ "$local_port" = "$filter_port" ]; then
      return 0
    fi
  done <<EOF
$rows
EOF

  return 1
}

pid_has_forward() {
  wanted_pid="$1"
  rows="$(collect_forward_rows)"

  while IFS='|' read -r pid local_port spec; do
    [ -n "$pid" ] || continue
    [ -n "$local_port" ] || continue
    [ -n "$spec" ] || continue
    if [ "$pid" = "$wanted_pid" ]; then
      return 0
    fi
  done <<EOF
$rows
EOF

  return 1
}

ensure_no_forward_on_port() {
  local_port="$1"
  validate_port "$local_port"

  if port_has_forward "$local_port"; then
    printf 'fleet: local port %s already has an active SSH forward.\n' "$local_port" >&2
    printf '%s\n' 'fleet: stop the existing forward before opening another one:' >&2
    list_forwards "$local_port" >&2
    exit 1
  fi
}

stop_forwards() {
  if [ "$#" -eq 0 ]; then
    echo "fleet: expected one or more forward PIDs" >&2
    exit 2
  fi

  for pid in "$@"; do
    case "$pid" in
      ""|*[!0-9]*)
        echo "fleet: forward PID must be numeric: $pid" >&2
        exit 2
        ;;
    esac

    if ! pid_has_forward "$pid"; then
      echo "fleet: PID $pid is not an active SSH local forward" >&2
      exit 1
    fi
  done

  for pid in "$@"; do
    if kill "$pid"; then
      printf 'fleet: stopped SSH forward process %s\n' "$pid"
    else
      echo "fleet: failed to stop SSH forward process $pid" >&2
      exit 1
    fi
  done
}

ssh_forward() {
  exec ssh \
    -o ExitOnForwardFailure=yes \
    -o ForwardAgent=no \
    -o ControlMaster=no \
    -o ControlPath=none \
    -N \
    -L "$1" \
    "fleet-forward-$2"
}

normalize_ssh_forward() {
  requested="$1"
  case "$requested" in
    *:*)
      local_port="${requested%%:*}"
      remote_port="${requested#*:}"
      case "$remote_port" in
        *:*)
          echo "fleet: SSH forwards use PORT or LOCAL_PORT:REMOTE_PORT" >&2
          exit 2
          ;;
      esac
      ;;
    *)
      local_port="$requested"
      remote_port="$requested"
      ;;
  esac

  validate_port "$local_port"
  validate_port "$remote_port"
  printf '127.0.0.1:%s:localhost:%s\n' "$local_port" "$remote_port"
}

remote_tmux_command() {
  case "$1" in
    # @REMOTE_TMUX_ROWS@
    *) printf '%s\n' tmux ;;
  esac
}

t3code_port() {
  case "$1" in
    # @T3CODE_PORT_ROWS@
    *)
      echo "fleet: host does not declare a T3 Code port: $1" >&2
      exit 2
      ;;
  esac
}

usage() {
  printf '%s\n' \
    'usage:' \
    '  fleet list' \
    '  fleet ssh HOST [SESSION] [--forward PORT|LOCAL_PORT:REMOTE_PORT]...' \
    '  fleet shell HOST' \
    '  fleet run HOST COMMAND...' \
    '  fleet forward HOST LOCAL_PORT REMOTE_PORT [REMOTE_HOST]' \
    '  fleet forward list [LOCAL_PORT]' \
    '  fleet forward stop PID...' \
    '  fleet forward delete PID...' \
    '  fleet t3 HOST [LOCAL_PORT]' \
    "" \
    'examples:' \
    '  fleet ssh kim' \
    '  fleet ssh kim agents --forward 3000 --forward 5173' \
    '  fleet shell kim' \
    '  fleet run kim btop' \
    '  fleet forward kim 3000 3000' \
    '  fleet forward list 3000' \
    '  fleet forward delete 12345' \
    '  fleet t3 kim 51001'
}

cmd="${1:-list}"

case "$cmd" in
  list)
    # @CURRENT_HOST@
    printf '%-18s %-12s %-24s %-16s %-8s %s\n' HOST USER TARGET ROLE CLIENT ALIASES
    # @HOST_ROWS@
    ;;
  ssh)
    if [ "$#" -lt 2 ]; then
      usage >&2
      exit 2
    fi
    host="$2"
    shift 2
    session=
    forward_specs=()
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --forward)
          if [ "$#" -lt 2 ]; then
            echo "fleet: --forward requires PORT or LOCAL_PORT:REMOTE_PORT" >&2
            exit 2
          fi
          forward_specs+=("$2")
          shift 2
          ;;
        --*)
          echo "fleet: unknown SSH option: $1" >&2
          exit 2
          ;;
        *)
          if [ -n "$session" ]; then
            echo "fleet: expected at most one tmux session name" >&2
            exit 2
          fi
          session="$1"
          validate_session "$session"
          shift
          ;;
      esac
    done

    if is_local_host "$host"; then
      if [ "${#forward_specs[@]}" -gt 0 ]; then
        echo "fleet: --forward requires a remote Fleet host" >&2
        exit 2
      fi
      session="${session:-main}"
      validate_session "$session"
      exec tmux new-session -A -s "$session"
    fi

    ssh_forward_args=()
    if [ "${#forward_specs[@]}" -gt 0 ]; then
      # Keep project forwards scoped to this attachment rather than a
      # shared ControlPersist master that can outlive it.
      ssh_forward_args+=(
        -o ExitOnForwardFailure=yes
        -o ControlMaster=no
        -o ControlPath=none
      )
      for requested_forward in "${forward_specs[@]}"; do
        normalized_forward="$(normalize_ssh_forward "$requested_forward")"
        local_port="$(forward_local_port "$normalized_forward")"
        ensure_no_forward_on_port "$local_port"
        ssh_forward_args+=(-L "$normalized_forward")
      done
    fi

    if [ -n "$session" ]; then
      tmux_command="$(remote_tmux_command "$host")"
      exec ssh -t "${ssh_forward_args[@]}" "$host" "$tmux_command new-session -A -s '$session'"
    fi
    exec ssh "${ssh_forward_args[@]}" "tm-$host"
    ;;
  shell)
    if [ "$#" -lt 2 ]; then
      usage >&2
      exit 2
    fi
    shift
    if is_local_host "$1"; then
      exec "${SHELL:-/bin/sh}"
    fi
    exec ssh "$@"
    ;;
  run)
    if [ "$#" -lt 3 ]; then
      usage >&2
      exit 2
    fi
    host="$2"
    shift 2
    if is_local_host "$host"; then
      exec "$@"
    fi
    exec ssh "$host" "$@"
    ;;
  forward)
    case "${2:-}" in
      list|ls)
        if [ "$#" -gt 3 ]; then
          usage >&2
          exit 2
        fi
        list_forwards "${3:-}"
        ;;
      stop|delete|rm)
        shift 2
        stop_forwards "$@"
        ;;
      *)
        if [ "$#" -lt 4 ]; then
          usage >&2
          exit 2
        fi
        host="$2"
        requested_local_port="$3"
        remote_port="$4"
        remote_host="${5:-localhost}"
        validate_port "$remote_port"
        ensure_no_forward_on_port "$requested_local_port"
        ssh_forward "127.0.0.1:$requested_local_port:$remote_host:$remote_port" "$host"
        ;;
    esac
    ;;
  t3)
    if [ "$#" -lt 2 ]; then
      usage >&2
      exit 2
    fi
    host="$2"
    remote_port="$(t3code_port "$host")"
    local_port="${3:-$remote_port}"
    ensure_no_forward_on_port "$local_port"
    ssh_forward "127.0.0.1:$local_port:127.0.0.1:$remote_port" "$host"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "fleet: unknown command: $cmd" >&2
    usage >&2
    exit 2
    ;;
esac
