# shellcheck shell=bash
# Explicit rebuild process tracking. This deliberately never infers processes
# from build logs, derivation names, or repository-wide regular expressions.

rebuild_state_init_paths() {
    REBUILD_STATE_DIR="${NIX_CONFIG_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/nix-config}"
    REBUILD_STATE_FILE="$REBUILD_STATE_DIR/rebuild.state"
}

rebuild_process_start() {
    ps -p "$1" -o lstart= 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

rebuild_process_command() {
    ps -p "$1" -o command= 2>/dev/null
}

rebuild_state_metadata() {
    if stat -c '%u:%g:%a' "$REBUILD_STATE_FILE" 2>/dev/null; then
        return 0
    fi
    stat -f '%u:%g:%Lp' "$REBUILD_STATE_FILE" 2>/dev/null
}

read_rebuild_state() {
    local key value
    rebuild_state_init_paths
    REBUILD_PID=""
    REBUILD_START=""
    [[ -f "$REBUILD_STATE_FILE" ]] || return 1

    while IFS='=' read -r key value; do
        case "$key" in
            pid) REBUILD_PID="$value" ;;
            start) REBUILD_START="$value" ;;
        esac
    done <"$REBUILD_STATE_FILE"

    case "$REBUILD_PID" in
        ""|*[!0-9]*) return 1 ;;
    esac
    [[ -n "$REBUILD_START" ]]
}

validate_rebuild_state() {
    local actual_start actual_command metadata state_uid state_gid state_mode
    read_rebuild_state || return 1
    metadata=$(rebuild_state_metadata) || return 1
    IFS=: read -r state_uid state_gid state_mode <<<"$metadata"
    [[ "$state_uid" == "$(id -u)" && "$state_gid" =~ ^[0-9]+$ && "$state_mode" == "600" ]] || return 1
    actual_start=$(rebuild_process_start "$REBUILD_PID") || return 1
    [[ -n "$actual_start" && "$actual_start" == "$REBUILD_START" ]] || return 1
    actual_command=$(rebuild_process_command "$REBUILD_PID") || return 1
    case "$actual_command" in
        *nixos-rebuild.sh*) return 0 ;;
        *) return 1 ;;
    esac
}

write_rebuild_state_for_pid() {
    local pid="$1"
    local start
    rebuild_state_init_paths
    start=$(rebuild_process_start "$pid")
    [[ -n "$start" ]] || return 1
    umask 077
    mkdir -p "$REBUILD_STATE_DIR"
    {
        printf 'pid=%s\n' "$pid"
        printf 'start=%s\n' "$start"
    } >"$REBUILD_STATE_FILE"
    chmod 600 "$REBUILD_STATE_FILE"
}

register_rebuild_process() {
    rebuild_state_init_paths
    if [[ -e "$REBUILD_STATE_FILE" ]]; then
        if validate_rebuild_state; then
            echo "A rebuild is already active at PID $REBUILD_PID." >&2
            echo "Use 'make rebuild-processes' to inspect it." >&2
            return 1
        fi
        rm -f "$REBUILD_STATE_FILE"
    fi
    write_rebuild_state_for_pid "$$"
}

remove_rebuild_state() {
    rebuild_state_init_paths
    if read_rebuild_state && [[ "$REBUILD_PID" == "$$" ]]; then
        rm -f "$REBUILD_STATE_FILE"
    fi
}

rebuild_descendants() {
    local root="$1"
    local frontier="$root"
    local seen="$root"
    local next pid ppid parent
    local process_rows

    process_rows=$(ps -axo pid=,ppid=)
    while [[ -n "$frontier" ]]; do
        next=""
        for parent in $frontier; do
            while read -r pid ppid; do
                [[ "$ppid" == "$parent" ]] || continue
                case " $seen " in
                    *" $pid "*) ;;
                    *)
                        seen="$seen $pid"
                        next="$next $pid"
                        printf '%s\n' "$pid"
                        ;;
                esac
            done <<<"$process_rows"
        done
        frontier="$next"
    done
}

tracked_rebuild_pids() {
    validate_rebuild_state || return 1
    printf '%s\n' "$REBUILD_PID"
    rebuild_descendants "$REBUILD_PID"
}

list_rebuild_processes() {
    local pids csv
    if ! pids=$(tracked_rebuild_pids); then
        echo "No active tracked rebuild."
        return 0
    fi
    csv=$(printf '%s\n' "$pids" | paste -sd, -)
    ps -p "$csv" -o pid,ppid,pgid,stat,etime,command
}

cleanup_rebuild_processes() {
    local pids pid remaining="" termination_order="" sudo_term="" sudo_kill=""
    if ! pids=$(tracked_rebuild_pids); then
        echo "No active tracked rebuild."
        return 0
    fi

    echo "Stopping the tracked rebuild process tree:"
    list_rebuild_processes
    # Reverse breadth-first discovery so children receive TERM before the root
    # removes its state in the EXIT trap.
    for pid in $pids; do
        termination_order="$pid $termination_order"
    done
    for pid in $termination_order; do
        if ! kill -TERM "$pid" 2>/dev/null; then
            sudo_term="$sudo_term $pid"
        fi
    done
    if [[ -n "$sudo_term" ]]; then
        echo "Elevating only for tracked PIDs owned by the Nix daemon:$sudo_term"
        # shellcheck disable=SC2086
        sudo kill -TERM $sudo_term
    fi

    for _ in 1 2 3 4 5; do
        remaining=""
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then
                remaining="$remaining $pid"
            fi
        done
        [[ -z "$remaining" ]] && break
        sleep 1
    done

    if [[ -n "$remaining" ]]; then
        echo "Sending KILL to remaining tracked PIDs:$remaining"
        for pid in $remaining; do
            if ! kill -KILL "$pid" 2>/dev/null; then
                sudo_kill="$sudo_kill $pid"
            fi
        done
        if [[ -n "$sudo_kill" ]]; then
            # shellcheck disable=SC2086
            sudo kill -KILL $sudo_kill
        fi
    fi
    rebuild_state_init_paths
    rm -f "$REBUILD_STATE_FILE"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    case "${1:-list}" in
        list) list_rebuild_processes ;;
        cleanup) cleanup_rebuild_processes ;;
        *)
            echo "usage: $0 [list|cleanup]" >&2
            exit 2
            ;;
    esac
fi
