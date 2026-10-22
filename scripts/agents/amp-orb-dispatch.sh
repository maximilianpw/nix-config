#!/usr/bin/env bash
# Amp's self-hosted orb dispatch contract: spawn, pause (with snapshots), delete.
set -euo pipefail

: "${DOCKER_BIN:?DOCKER_BIN must be set}"
: "${ORB_STATE_DIRECTORY:?ORB_STATE_DIRECTORY must be set}"
: "${ORB_CPUS:?ORB_CPUS must be set}"
: "${ORB_MEMORY:?ORB_MEMORY must be set}"
: "${ORB_PIDS_LIMIT:?ORB_PIDS_LIMIT must be set}"
: "${ORB_MAX_RUNNING:?ORB_MAX_RUNNING must be set}"
: "${ORB_OPERATION:?ORB_OPERATION must be set}"
: "${ORB_ID:?ORB_ID must be set}"

fail() {
  printf 'Amp orb dispatch: %s\n' "$*" >&2
  exit 1
}

case "$ORB_OPERATION" in
  spawn)
    : "${ORB_IMAGE:?ORB_IMAGE must be set for spawn}"
    : "${ORB_TOKEN:?ORB_TOKEN must be set for spawn}"
    ;;
  pause|delete) ;;
  *) fail "unsupported operation" ;;
esac

# Names never become options, filesystem paths, or arbitrary Docker selectors.
[[ "$ORB_ID" =~ ^amp-[a-zA-Z0-9][a-zA-Z0-9_.-]{0,119}$ ]] || fail "invalid ORB_ID"
name="amp-orb-$ORB_ID"
owner_label="pw.maximilian.amp-orb-provider"

# Serialize lifecycle changes, including capacity checks and snapshot publication.
# The Nix wrapper bounds the entire dispatch (including lock wait) to <5 minutes.
exec 9> "$ORB_STATE_DIRECTORY/dispatch.lock"
flock 9

# Listing instead of `inspect || run` distinguishes missing containers from daemon
# errors. A failed start must never silently create a fresh orb and lose its disk.
name_filter=${name//./\\.}
container_id=$("$DOCKER_BIN" container ls --all --filter "name=^/$name_filter$" --format '{{.ID}}')
running=false
if [[ -n "$container_id" ]]; then
  owner=$("$DOCKER_BIN" container inspect --format "{{index .Config.Labels \"$owner_label\"}}" "$name")
  [[ "$owner" == true ]] || fail "refusing to modify an unmanaged container"
  running=$("$DOCKER_BIN" container inspect --format '{{.State.Running}}' "$name")
fi

snapshot=""
if [[ -n "${ORB_SNAPSHOT_ID:-}" ]]; then
  # Snapshot IDs are opaque; hash them into a valid local-only Docker image tag.
  snapshot_hash=$(printf '%s' "$ORB_SNAPSHOT_ID" | sha256sum)
  snapshot="amp-orb-provider/snapshot:${snapshot_hash%% *}"
fi

case "$ORB_OPERATION" in
  spawn)
    if [[ "$running" != true ]]; then
      active=$("$DOCKER_BIN" container ls --filter "label=$owner_label=true" --format '{{.ID}}')
      count=0
      while IFS= read -r id; do
        [[ -z "$id" ]] || count=$((count + 1))
      done <<< "$active"
      (( count < ORB_MAX_RUNNING )) || fail "running orb limit reached"

      if [[ -n "$container_id" ]]; then
        "$DOCKER_BIN" container start "$name" >/dev/null
      else
        image="$ORB_IMAGE"
        if [[ -n "$snapshot" ]]; then
          saved=$("$DOCKER_BIN" image ls --quiet --filter "reference=$snapshot")
          [[ -z "$saved" ]] || image="$snapshot"
        fi
        "$DOCKER_BIN" container run --detach --init --platform linux/amd64 \
          --name "$name" --label "$owner_label=true" --label homelab.keep=true \
          --restart=no --cpus "$ORB_CPUS" --memory "$ORB_MEMORY" \
          --memory-swap "$ORB_MEMORY" --pids-limit "$ORB_PIDS_LIMIT" \
          --log-opt max-size=10m --log-opt max-file=3 \
          -- "$image" sleep infinity >/dev/null
      fi
    fi

    # Bare --env names keep tokens out of argv, container config and snapshots.
    # Do not forward AMP_ORB_PROVIDER_TOKEN or mount host homes/sockets/store.
    env_args=(--env ORB_TOKEN)
    if [[ -n "${AMP_URL:-}" ]]; then
      env_args+=(--env AMP_URL)
    fi
    # A lock held by the long-lived bootstrap prevents duplicate connections on
    # repeated spawn jobs. flock is supplied by util-linux in Amp's default image.
    # shellcheck disable=SC2016 # HOME expands inside the orb, not on the host.
    "$DOCKER_BIN" container exec --detach "${env_args[@]}" "$name" \
      bash -c 'exec flock --nonblock "$HOME/.amp-orb-bootstrap.lock" amp orb bootstrap'
    ;;
  pause)
    if [[ -n "$container_id" ]]; then
      if [[ "$running" == true ]]; then
        "$DOCKER_BIN" container stop --time 20 "$name" >/dev/null
      fi
      if [[ -n "$snapshot" ]]; then
        "$DOCKER_BIN" container commit "$name" "$snapshot" >/dev/null
      fi
    fi
    ;;
  delete)
    if [[ -n "$container_id" ]]; then
      "$DOCKER_BIN" container rm --force --volumes "$name" >/dev/null
    fi
    # Project snapshots are shared by threads, so deleting an orb retains them.
    ;;
esac
