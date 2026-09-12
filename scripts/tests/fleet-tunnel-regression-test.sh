#!/usr/bin/env bash
set -euo pipefail

if [[ -z ${FLEET_BIN:-} ]]; then
  printf '%s\n' 'fleet tunnel regression skipped: FLEET_BIN is supplied by the Nix check.'
  exit 0
fi
: "${out:?out must be set by Nix runCommand}"
: "${FLEET_KIM_BIN:?FLEET_KIM_BIN is supplied by the Nix check}"

export SSH_ARGS_LOG="$TMPDIR/ssh-args"
export SSH_ARGS_ALL="$TMPDIR/ssh-args-all"
export FLEET_LAUNCHCTL_STATE="$TMPDIR/launchctl-state"
export FLEET_LISTEN_FILE="$TMPDIR/listen-ports"
export FLEET_LISTENER_PIDS="$TMPDIR/listener-pids"
HOME="$TMPDIR/home"
export HOME
mkdir -p "$HOME/Library/LaunchAgents" "$TMPDIR/bin" "$FLEET_LAUNCHCTL_STATE"
: >"$SSH_ARGS_ALL"
: >"$FLEET_LISTEN_FILE"

label_for() {
  printf 'org.nix-community.home.fleet-tunnel-%s\n' "$1"
}

plist_for() {
  printf '%s/Library/LaunchAgents/%s.plist\n' "$HOME" "$(label_for "$1")"
}

printf 'placeholder\n' >"$(plist_for 3000)"
printf 'placeholder\n' >"$(plist_for 5173)"

cat >"$TMPDIR/bin/launchctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
state="${FLEET_LAUNCHCTL_STATE:?}"
log="${state}/commands"
printf '%s\n' "$*" >>"$log"
uid="$(id -u)"
domain="gui/$uid"

label_from_target() {
  target="$1"
  printf '%s\n' "${target##*/}"
}

disabled_file() {
  printf '%s/disabled/%s\n' "$state" "$1"
}

running_file() {
  printf '%s/running/%s\n' "$state" "$1"
}

loaded_file() {
  printf '%s/loaded/%s\n' "$state" "$1"
}

mkdir -p "$state/disabled" "$state/running" "$state/loaded"

cmd="${1:-}"
case "$cmd" in
  print-disabled)
    printf '%s\n' 'disabled services = {'
    for path in "$state"/disabled/*; do
      [ -e "$path" ] || continue
      printf '\t"%s" => %s\n' "${path##*/}" "${FLEET_DISABLED_FORMAT:-true}"
    done
    printf '%s\n' '}'
    ;;
  print)
    target="${2:-}"
    label="$(label_from_target "$target")"
    if [ ! -e "$(loaded_file "$label")" ] && [ ! -e "$(running_file "$label")" ]; then
      echo "Could not find service $target" >&2
      exit 1
    fi
    if [ -e "$(running_file "$label")" ]; then
      printf 'state = running\npid = %s\n' "$(cat "$(running_file "$label")")"
    else
      printf '%s\n' 'state = not running'
    fi
    ;;
  disable)
    label="$(label_from_target "${2:-}")"
    touch "$(disabled_file "$label")"
    ;;
  enable)
    label="$(label_from_target "${2:-}")"
    rm -f "$(disabled_file "$label")"
    ;;
  bootout)
    shift
    if [ "${1:-}" = --wait ]; then
      shift
    fi
    label="$(label_from_target "${1:-}")"
    rm -f "$(running_file "$label")" "$(loaded_file "$label")"
    ;;
  bootstrap)
    plist="${3:-}"
    label="$(basename "$plist" .plist)"
    if [ -e "$(disabled_file "$label")" ]; then
      touch "$(loaded_file "$label")"
      rm -f "$(running_file "$label")"
      exit 0
    fi
    touch "$(loaded_file "$label")"
    printf '42\n' >"$(running_file "$label")"
    ;;
  kickstart)
    label="$(label_from_target "${2:-}")"
    if [ -e "$(disabled_file "$label")" ]; then
      echo "kickstart failed: service disabled" >&2
      exit 1
    fi
    touch "$(loaded_file "$label")"
    printf '42\n' >"$(running_file "$label")"
    ;;
  *)
    echo "launchctl mock: unknown command $cmd" >&2
    exit 90
    ;;
esac
EOF
chmod +x "$TMPDIR/bin/launchctl"

cat >"$TMPDIR/bin/tcp-probe" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
host="$1"
port="$2"
grep -Fxq "${host}:${port}" "${FLEET_LISTEN_FILE:?}"
EOF
chmod +x "$TMPDIR/bin/tcp-probe"

cat >"$TMPDIR/bin/ps" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  '-p 43 -o ppid=,comm=') printf '42 /nix/store/fixture/bin/ssh\n' ;;
  '-p 44 -o ppid=,comm=') printf '43 /nix/store/fixture/bin/ssh\n' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$TMPDIR/bin/ps"
export FLEET_TCP_PROBE="$TMPDIR/bin/tcp-probe"
export PATH="$TMPDIR/bin:$PATH"

reset_tunnels() {
  rm -rf "$FLEET_LAUNCHCTL_STATE"
  mkdir -p "$FLEET_LAUNCHCTL_STATE/disabled" "$FLEET_LAUNCHCTL_STATE/running" "$FLEET_LAUNCHCTL_STATE/loaded"
  : >"$FLEET_LAUNCHCTL_STATE/commands"
  : >"$FLEET_LISTEN_FILE"
  : >"$SSH_ARGS_ALL"
  rm -rf "$FLEET_LISTENER_PIDS"
  mkdir -p "$FLEET_LISTENER_PIDS"
  rm -f "$SSH_ARGS_LOG"
}

start_job() {
  port="$1"
  label="$(label_for "$port")"
  touch "$FLEET_LAUNCHCTL_STATE/loaded/$label"
  printf '42\n' >"$FLEET_LAUNCHCTL_STATE/running/$label"
  printf '42\n' >"$FLEET_LISTENER_PIDS/$port"
  printf '127.0.0.1:%s\n' "$port" >>"$FLEET_LISTEN_FILE"
}

expect_success() {
  if ! "$@"; then
    echo "expected success: $*" >&2
    exit 1
  fi
}

expect_failure() {
  if "$@"; then
    echo "expected failure: $*" >&2
    exit 1
  fi
}

expect_file_contains() {
  file="$1"
  needle="$2"
  if ! grep -Fq "$needle" "$file"; then
    echo "missing '$needle' in $file:" >&2
    cat "$file" >&2
    exit 1
  fi
}

# Existing SSH dispatch still works with managed tunnels present.
reset_tunnels
"$FLEET_BIN" ssh kim
printf '%s\n' tm-kim >"$TMPDIR/expected-default"
diff -u "$TMPDIR/expected-default" "$SSH_ARGS_LOG"

list_output=$("$FLEET_BIN" list)
[[ $list_output == $'Current machine: joyce\n\n'* ]]

# CLI dispatch and status while both jobs run.
reset_tunnels
start_job 3000
start_job 5173
status=$("$FLEET_BIN" tunnel)
status_explicit=$("$FLEET_BIN" tunnel status)
[[ $status == "$status_explicit" ]]
expect_file_contains <(printf '%s\n' "$status") "3000"
expect_file_contains <(printf '%s\n' "$status") "5173"
expect_file_contains <(printf '%s\n' "$status") "running"
expect_file_contains <(printf '%s\n' "$status") "owned"

# Disabled state matches the entire label, not another port with the same prefix.
touch "$FLEET_LAUNCHCTL_STATE/disabled/$(label_for 30000)"
export FLEET_DISABLED_FORMAT=disabled
status=$("$FLEET_BIN" tunnel status)
if printf '%s\n' "$status" | grep -E '3000 .+paused' >/dev/null; then
  echo "disabled port 30000 incorrectly paused port 3000" >&2
  exit 1
fi

# Pause only the requested job and persist disable across a simulated relogin.
reset_tunnels
start_job 3000
start_job 5173
expect_success "$FLEET_BIN" tunnel pause 3000
expect_file_contains "$FLEET_LAUNCHCTL_STATE/commands" "disable gui/$(id -u)/$(label_for 3000)"
expect_file_contains "$FLEET_LAUNCHCTL_STATE/commands" "bootout --wait gui/$(id -u)/$(label_for 3000)"
if grep -Fq "$(label_for 5173)" "$FLEET_LAUNCHCTL_STATE/commands"; then
  echo "pause 3000 touched the 5173 job" >&2
  cat "$FLEET_LAUNCHCTL_STATE/commands" >&2
  exit 1
fi
test -e "$FLEET_LAUNCHCTL_STATE/disabled/$(label_for 3000)"
test ! -e "$FLEET_LAUNCHCTL_STATE/running/$(label_for 3000)"
test -e "$FLEET_LAUNCHCTL_STATE/running/$(label_for 5173)"

# Relogin: jobs unload, disable override remains.
rm -f "$FLEET_LAUNCHCTL_STATE/running/"* "$FLEET_LAUNCHCTL_STATE/loaded/"* "$FLEET_LISTENER_PIDS/"*
: >"$FLEET_LISTEN_FILE"
paused_status=$("$FLEET_BIN" tunnel status)
expect_file_contains <(printf '%s\n' "$paused_status") "paused"
expect_file_contains <(printf '%s\n' "$paused_status") "3000"
if printf '%s\n' "$paused_status" | grep -E '3000.+(running|owned)' >/dev/null; then
  echo "paused tunnel reported running after relogin" >&2
  exit 1
fi

# Activation-style bootstrap of a disabled job must not start it.
"$TMPDIR/bin/launchctl" bootstrap "gui/$(id -u)" "$(plist_for 3000)"
test -e "$FLEET_LAUNCHCTL_STATE/loaded/$(label_for 3000)"
test ! -e "$FLEET_LAUNCHCTL_STATE/running/$(label_for 3000)"
test -e "$FLEET_LAUNCHCTL_STATE/disabled/$(label_for 3000)"

# Occupied unrelated port: resume refuses and keeps pause.
printf '127.0.0.1:3000\n' >"$FLEET_LISTEN_FILE"
if "$FLEET_BIN" tunnel resume 3000 >"$TMPDIR/resume.out" 2>"$TMPDIR/resume.err"; then
  echo "resume succeeded while an unrelated process owned the port" >&2
  exit 1
fi
expect_file_contains "$TMPDIR/resume.err" "unrelated process"
expect_file_contains "$TMPDIR/resume.err" "not killing"
test -e "$FLEET_LAUNCHCTL_STATE/disabled/$(label_for 3000)"
if grep -Eq '^(enable|kickstart) ' "$FLEET_LAUNCHCTL_STATE/commands"; then
  echo "resume enabled a tunnel while the port was occupied" >&2
  cat "$FLEET_LAUNCHCTL_STATE/commands" >&2
  exit 1
fi

# Resume after the occupant leaves.
: >"$FLEET_LISTEN_FILE"
: >"$FLEET_LAUNCHCTL_STATE/commands"
expect_success "$FLEET_BIN" tunnel resume 3000
expect_file_contains "$FLEET_LAUNCHCTL_STATE/commands" "enable gui/$(id -u)/$(label_for 3000)"
test ! -e "$FLEET_LAUNCHCTL_STATE/disabled/$(label_for 3000)"
test -e "$FLEET_LAUNCHCTL_STATE/running/$(label_for 3000)"

# Doctor: healthy tunnel is not claimed from local listen alone.
reset_tunnels
start_job 3000
start_job 5173
export FLEET_SSH_STATUS=ok
export FLEET_REMOTE_LISTEN=up
export FLEET_SSH_CONSUME_STDIN=yes
expect_success "$FLEET_BIN" doctor kim >"$TMPDIR/doctor-ok.out"
expect_file_contains "$TMPDIR/doctor-ok.out" "SSH: reachable"
expect_file_contains "$TMPDIR/doctor-ok.out" "tunnel 3000: supervisor=running local=owned remote=listening"
expect_file_contains "$TMPDIR/doctor-ok.out" "tunnel 5173: supervisor=running local=owned remote=listening"
expect_file_contains "$SSH_ARGS_ALL" "BatchMode=yes"
expect_file_contains "$SSH_ARGS_ALL" "ConnectTimeout=10"
expect_file_contains "$SSH_ARGS_ALL" "ControlMaster=no"
expect_file_contains "$SSH_ARGS_ALL" "ForwardAgent=no"
expect_file_contains "$SSH_ARGS_ALL" "/dev/tcp/"
if grep -Ei 'end-to-end healthy|everything is healthy' "$TMPDIR/doctor-ok.out"; then
  echo "doctor claimed generic end-to-end health" >&2
  exit 1
fi

# Kim uses fish: SSH's remote command must parse in fish, not just Bash.
export FLEET_SSH_STATUS=fish-syntax
expect_success "$FLEET_BIN" doctor kim >"$TMPDIR/doctor-fish.out"
expect_file_contains "$TMPDIR/doctor-fish.out" "tunnel 5173:"
export FLEET_SSH_STATUS=ok

# Aliases resolve to the same mapping set, unknown hosts fail before SSH.
expect_success "$FLEET_BIN" doctor main-pc >"$TMPDIR/doctor-alias.out"
expect_file_contains "$TMPDIR/doctor-alias.out" "tunnel 3000:"
rm -f "$SSH_ARGS_LOG"
expect_failure "$FLEET_BIN" doctor --bad-host >"$TMPDIR/doctor-unknown.out" 2>&1
test ! -e "$SSH_ARGS_LOG"

# The runner's direct SSH child owns the listener, not arbitrary descendants.
printf '43\n' >"$FLEET_LISTENER_PIDS/3000"
expect_success "$FLEET_BIN" doctor kim >"$TMPDIR/doctor-child.out"
expect_file_contains "$TMPDIR/doctor-child.out" "supervisor=running local=owned"
printf '44\n' >"$FLEET_LISTENER_PIDS/3000"
expect_failure "$FLEET_BIN" doctor kim >"$TMPDIR/doctor-grandchild.out"
expect_file_contains "$TMPDIR/doctor-grandchild.out" "supervisor=running local=unrelated"

# A running SSH job may still be authenticating while another PID owns the port.
printf '99\n' >"$FLEET_LISTENER_PIDS/3000"
expect_failure "$FLEET_BIN" doctor kim >"$TMPDIR/doctor-conflict.out"
expect_file_contains "$TMPDIR/doctor-conflict.out" "supervisor=running local=unrelated"
expect_failure "$FLEET_BIN" tunnel resume 3000 >"$TMPDIR/resume-conflict.out" 2>&1
expect_file_contains "$TMPDIR/resume-conflict.out" "unrelated process"
printf '42\n' >"$FLEET_LISTENER_PIDS/3000"

# Remote app down: local owned listener is not enough.
export FLEET_REMOTE_LISTEN=down
: >"$SSH_ARGS_ALL"
if "$FLEET_BIN" doctor kim >"$TMPDIR/doctor-remote.out" 2>&1; then
  echo "doctor succeeded while the remote app was down" >&2
  cat "$TMPDIR/doctor-remote.out" >&2
  exit 1
fi
expect_file_contains "$TMPDIR/doctor-remote.out" "SSH: reachable"
expect_file_contains "$TMPDIR/doctor-remote.out" "remote=down"
expect_file_contains "$TMPDIR/doctor-remote.out" "unhealthy: remote app is not listening on kim localhost:3000"
expect_file_contains "$TMPDIR/doctor-remote.out" "local=owned"

# Unrelated local occupant while the job is down.
reset_tunnels
export FLEET_REMOTE_LISTEN=up
printf '127.0.0.1:3000\n' >"$FLEET_LISTEN_FILE"
if "$FLEET_BIN" doctor kim >"$TMPDIR/doctor-unrelated.out" 2>&1; then
  echo "doctor succeeded with an unrelated local listener" >&2
  exit 1
fi
expect_file_contains "$TMPDIR/doctor-unrelated.out" "local=unrelated"
expect_file_contains "$TMPDIR/doctor-unrelated.out" "unhealthy: local port 3000 is occupied by an unrelated process"

# SSH unavailable vs auth failure. Remote probes must not run after SSH failure.
reset_tunnels
start_job 3000
export FLEET_SSH_STATUS=unavailable
: >"$SSH_ARGS_ALL"
if "$FLEET_BIN" doctor kim >"$TMPDIR/doctor-unavail.out" 2>&1; then
  echo "doctor succeeded while SSH was unavailable" >&2
  exit 1
fi
expect_file_contains "$TMPDIR/doctor-unavail.out" "SSH: unavailable"
expect_file_contains "$TMPDIR/doctor-unavail.out" "unhealthy: SSH to kim is unavailable"
expect_file_contains "$TMPDIR/doctor-unavail.out" "remote=skipped"
if grep -Fq "/dev/tcp/" "$SSH_ARGS_ALL"; then
  echo "doctor probed remote TCP after SSH was unavailable" >&2
  cat "$SSH_ARGS_ALL" >&2
  exit 1
fi

export FLEET_SSH_STATUS=auth
: >"$SSH_ARGS_ALL"
if "$FLEET_BIN" doctor kim >"$TMPDIR/doctor-auth.out" 2>&1; then
  echo "doctor succeeded while SSH auth failed" >&2
  exit 1
fi
expect_file_contains "$TMPDIR/doctor-auth.out" "SSH: auth failure"
expect_file_contains "$TMPDIR/doctor-auth.out" "unhealthy: SSH to kim failed authentication"
if grep -Fq "/dev/tcp/" "$SSH_ARGS_ALL"; then
  echo "doctor probed remote TCP after SSH auth failure" >&2
  exit 1
fi

# Paused mapping does not fail doctor by itself when SSH works.
reset_tunnels
export FLEET_SSH_STATUS=ok
export FLEET_REMOTE_LISTEN=up
start_job 5173
touch "$FLEET_LAUNCHCTL_STATE/disabled/$(label_for 3000)"
expect_success "$FLEET_BIN" doctor kim >"$TMPDIR/doctor-paused.out"
expect_file_contains "$TMPDIR/doctor-paused.out" "tunnel 3000: supervisor=paused"

# Reconnect failure during a remote probe must not be called an app failure.
export FLEET_REMOTE_LISTEN=ssh-failed
expect_failure "$FLEET_BIN" doctor kim >"$TMPDIR/doctor-probe-failed.out"
expect_file_contains "$TMPDIR/doctor-probe-failed.out" "remote=unknown"
if grep -Fq 'remote app is not listening' "$TMPDIR/doctor-probe-failed.out"; then
  echo "doctor mislabeled SSH failure as remote app failure" >&2
  exit 1
fi

# Wall-clock deadlines also cover agent waits and stuck remote commands.
export FLEET_SSH_STATUS=hang
SECONDS=0
expect_failure "$FLEET_BIN" doctor kim >"$TMPDIR/doctor-timeout.out"
[[ $SECONDS -lt 25 ]]
expect_file_contains "$TMPDIR/doctor-timeout.out" "SSH: unavailable"
export FLEET_SSH_STATUS=ok
export FLEET_REMOTE_LISTEN=hang
SECONDS=0
expect_failure "$FLEET_BIN" doctor kim >"$TMPDIR/doctor-probe-timeout.out"
[[ $SECONDS -lt 25 ]]
expect_file_contains "$TMPDIR/doctor-probe-timeout.out" "remote=unknown"
export FLEET_REMOTE_LISTEN=up

# Non-Darwin fleet keeps existing commands and explains managed tunnel ops.
export FLEET_SSH_STATUS=ok
expect_success "$FLEET_KIM_BIN" list >/dev/null
if "$FLEET_KIM_BIN" tunnel pause 3000 >"$TMPDIR/kim-pause.out" 2>"$TMPDIR/kim-pause.err"; then
  echo "kim fleet pause unexpectedly succeeded" >&2
  exit 1
fi
expect_file_contains "$TMPDIR/kim-pause.err" "macOS launchd"
expect_success "$FLEET_KIM_BIN" doctor joyce >"$TMPDIR/kim-doctor.out"
expect_file_contains "$TMPDIR/kim-doctor.out" "SSH: reachable"
expect_file_contains "$TMPDIR/kim-doctor.out" "No managed tunnels configured on this host."

if "$FLEET_BIN" tunnel pause 9 2>"$TMPDIR/missing-port.err"; then
  echo "pause of an undeclared port succeeded" >&2
  exit 1
fi
expect_file_contains "$TMPDIR/missing-port.err" "no managed tunnel"

# Startup deadline terminates only our SSH child when authentication stalls.
export FLEET_TUNNEL_STARTUP_SECONDS=1
export FLEET_SSH_STATUS=hang
export FLEET_STARTUP_LISTEN=no
SECONDS=0
expect_failure "$FLEET_TUNNEL_RUNNER" 3000 -N -L 127.0.0.1:3000:localhost:3000 fleet-forward-kim
[[ $SECONDS -lt 10 ]]

# Once the child owns its listener, the startup deadline is not a lifetime cap.
export FLEET_SSH_STATUS=slow-success
export FLEET_STARTUP_LISTEN=yes
SECONDS=0
expect_success "$FLEET_TUNNEL_RUNNER" 3000 -N -L 127.0.0.1:3000:localhost:3000 fleet-forward-kim
[[ $SECONDS -ge 3 ]]

# Stopping the runner releases its own child immediately, including startup.
export FLEET_TUNNEL_STARTUP_SECONDS=45
export FLEET_SSH_STATUS=hang
export FLEET_SSH_PID_LOG="$TMPDIR/runner-child-pid"
"$FLEET_TUNNEL_RUNNER" 3000 -N -L 127.0.0.1:3000:localhost:3000 fleet-forward-kim &
runner_pid=$!
for _ in {1..50}; do
  [[ -s $FLEET_SSH_PID_LOG ]] && break
  sleep 0.1
done
test -s "$FLEET_SSH_PID_LOG"
child_pid=$(<"$FLEET_SSH_PID_LOG")
kill "$runner_pid"
wait "$runner_pid" || true
if kill -0 "$child_pid" 2>/dev/null; then
  echo "stopping the runner left its SSH child alive" >&2
  exit 1
fi

touch "$out"
