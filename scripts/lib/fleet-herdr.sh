# shellcheck shell=sh

fleet_herdr_validate_name() {
    case "${1:-}" in
        ""|*[!A-Za-z0-9_.-]*)
            echo "fleet: Herdr host and label may only contain A-Z, a-z, 0-9, _, ., and -" >&2
            return 2
            ;;
    esac
}

fleet_herdr_close_workspace() {
    herdr workspace close "$1" >/dev/null 2>&1 || true
}

fleet_herdr_workspace() {
    fleet_herdr_host="$1"
    fleet_herdr_label="${2:-$1}"

    fleet_herdr_validate_name "$fleet_herdr_host"
    fleet_herdr_validate_name "$fleet_herdr_label"

    if ! fleet_herdr_workspace_json="$(herdr workspace create --label "$fleet_herdr_label" --focus)"; then
        echo "fleet: failed to create Herdr workspace" >&2
        return 1
    fi

    if ! fleet_herdr_workspace_id="$(
        printf '%s\n' "$fleet_herdr_workspace_json" |
            jq -er '[.. | objects | (.workspace_id? // empty) | select(type == "string" and length > 0)][0]'
    )"; then
        echo "fleet: Herdr did not return a workspace ID" >&2
        return 1
    fi

    if ! fleet_herdr_panes_json="$(herdr pane list --workspace "$fleet_herdr_workspace_id")"; then
        fleet_herdr_close_workspace "$fleet_herdr_workspace_id"
        echo "fleet: failed to inspect the new Herdr workspace" >&2
        return 1
    fi

    if ! fleet_herdr_pane_id="$(
        printf '%s\n' "$fleet_herdr_panes_json" |
            jq -er '[.. | objects | (.pane_id? // empty) | select(type == "string" and length > 0)][0]'
    )"; then
        fleet_herdr_close_workspace "$fleet_herdr_workspace_id"
        echo "fleet: Herdr did not return a pane for the new workspace" >&2
        return 1
    fi

    if ! herdr pane run "$fleet_herdr_pane_id" "exec fleet ssh $fleet_herdr_host" >/dev/null; then
        fleet_herdr_close_workspace "$fleet_herdr_workspace_id"
        echo "fleet: failed to start the Fleet session in Herdr" >&2
        return 1
    fi
}
