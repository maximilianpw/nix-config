# Revachol Fleet

Revachol is the name of this repo's remote development fleet. The operational
CLI remains `fleet`.

Home Manager installs the Rust package and module from the pinned `fleet`
flake input. `lib/fleet.nix` projects the personal inventory into the v1 TOML
schema while retaining SSH settings, trust exports, aliases, and the legacy
Bash package as a regression oracle. `tests/fleet-rust-integration.nix` checks
the pinned package/module and can still accept an explicit checkout during
migration work.

## Commands

- `fleet` or `fleet list` identifies the current machine, then shows every
  declared machine and its aliases.
- `fleet ssh <host> [session] [--forward <port-or-map>...]` connects to a
  persistent tmux session with optional project ports. The default session is
  `main`; a port maps to itself and `local:remote` remaps it.
- `fleet shell <host>` opens a plain SSH shell with no forced tmux command.
- `fleet run <host> <command...>` runs a non-interactive command remotely.
- `fleet forward <host> <local-port> <remote-port> [remote-host]` opens an SSH
  local forward. The default remote host is `localhost`, which covers services
  bound to either IPv4 or IPv6 loopback; pass `[remote-host]` for non-loopback
  targets.
- `fleet forward list [local-port]` shows active SSH local forwards and prints
  `fleet forward delete <pid>` commands for stopping them.
- `fleet forward stop <pid...>` or `fleet forward delete <pid...>` stops active
  SSH local forward processes.
- `fleet t3 <host> [local-port]` forwards a host's declared T3 Code server port.
- `fleet tunnel status` shows login-supervised localhost forwards declared for this machine.
- `fleet tunnel pause <port>` / `fleet tunnel resume <port>` persist a Darwin launchd pause without killing unrelated listeners.
- `fleet doctor <host>` checks SSH reachability, supervisor state, local port ownership, and whether the remote app accepts TCP.

For Herdr, use the native saved machines described below. `fleet ssh` remains
an independent tmux workflow: the remote tmux session owns its shells and
agents, so losing SSH does not stop them. Rerun the same command and session
name to reattach. Agents inside tmux over plain SSH are not included in Herdr's
combined agent list.

Add `--forward 3000` to expose the remote loopback port on the same local port,
or `--forward 3000:5173` to map local port 3000 to remote port 5173. The option
is repeatable. The same SSH process establishes every forward before attaching
tmux, so the remote app can start afterward. The forwards close with that SSH
attachment:

```sh
fleet ssh kim agents --forward 3000 --forward 5173
```

Use standalone `fleet forward` when a tunnel must remain independent of the
tmux attachment. Use `fleet tunnel` for the login-supervised Joyce localhost
forwards that should survive closing the terminal.

## Managed localhost tunnels

Joyce declares two persistent localhost forwards to Kim: local `3000` to Kim
`localhost:3000`, and local `5173` to Kim `localhost:5173`. Edit the defaults in
`modules/fleet/default-tunnels.nix` to change these mappings. The typed option is
`fleet.tunnels.mappings` in `modules/fleet/home-manager.nix`. Home Manager
installs one user LaunchAgent per local port
(`org.nix-community.home.fleet-tunnel-<port>`). That is Home Manager's
`launchd.agents`, not nix-darwin `launchd.user.agents`. No Kim-side service is
required: the remote process only has to listen on loopback.

Each job starts at login (`RunAtLoad`) and retries on failure (`KeepAlive`)
with a 30-second `ThrottleInterval`. A small runner owns one `ssh -N` child,
using the `fleet-forward-<host>` alias so pinned host keys and the 1Password
`IdentityAgent` still apply. Extra argv flags force `BatchMode`, a 10s connect
timeout, `ExitOnForwardFailure`, SSH keepalives, no multiplexing, no agent
forwarding, and `127.0.0.1` as the local bind address. Open your Mac's browser at
`http://localhost:3000` or `http://localhost:5173`. Browsers normally fall back
to IPv4 for localhost. IPv6-only clients need `127.0.0.1` instead: these jobs do
not bind `::1`. Changing the hostname to `127.0.0.1` changes the browser origin,
so keep `localhost` for projects whose authentication callbacks require it.

Use Herdr's saved Kim machine for project terminals and agents. These tunnels
are independent of Herdr and tmux: do not also request `fleet forward` or
`fleet ssh --forward` on a managed local port. Use `fleet tunnel pause PORT`
before running a project locally or using an ad-hoc forward on that port;
`fleet forward delete PID` would merely cause a supervised SSH job to restart.
Starting the remote app is still the project's responsibility. Prefer a fixed
port and fail on collisions rather than silently choosing a different port.

A reconnect still needs the existing 1Password SSH agent to authorize it.
`BatchMode` prevents password prompts in SSH, but does not bypass 1Password's
lock/approval policy. If reconnects fail after sleep, unlock 1Password, approve
any required SSH request, and let launchd retry. The runner checks after 45
seconds that its own SSH child has bound the local listener; otherwise it
terminates that child so launchd can retry (plus at most 4 seconds for the
listener probe). This startup deadline does not
limit a healthy tunnel's lifetime.

`fleet tunnel pause 3000` runs `launchctl disable` for that labeled job and
boots it out. The disabled override lives outside the plist, so it survives
logout, login, and Home Manager activation. Activation only re-bootstraps an
agent when its plist contents change, and launchd still honors disable. Pause
never sends signals to an unrelated listener. `fleet tunnel resume 3000` enables
and starts that job. If another process already owns the local port, resume
refuses, leaves the pause in place, and does not kill the occupant.

There is no dedicated tunnel log file: SSH stdout/stderr are discarded, not
automatically captured by the unified log. This avoids unbounded retry logs.
Inspect launchd's lifecycle state and last exit code with
`launchctl print gui/$UID/org.nix-community.home.fleet-tunnel-3000`, and use
`fleet doctor kim` for fresh connectivity checks.

`fleet doctor kim` (or a Fleet alias such as `main-pc`) is read-only, needs no
sudo, and applies a 15-second wall-clock timeout to each SSH check plus a
2-second forced-exit grace period. It distinguishes reachable SSH from
unavailability and authentication failure, reports each mapping's
supervisor/pause state, verifies the listener belongs to the job or its direct
SSH child, and TCP-probes the remote app (not HTTP). Remote probes require Bash and
`timeout`, already available on Kim. An SSH/probe failure is reported as
unknown rather than incorrectly calling the app down. A local listener is
not treated as end-to-end health: if the tunnel is up and the remote app is
down, doctor fails. Intentionally paused mappings skip the remote probe and
do not make the command fail; the host-level SSH check still runs.

After an explicitly approved Joyce activation, verify:

```sh
fleet tunnel status
fleet doctor kim
# Start the project on Kim, then open http://localhost:3000 on the Mac.
fleet tunnel pause 3000   # Frees the port for a local app; survives login.
fleet tunnel resume 3000  # Run after stopping the local app.
```

Sleep/wake, a temporary network outage, and locked-agent recovery need a live
acceptance test after activation. Unit tests exercise supervisor state and
failures with disposable mocks; they do not prove actual launchd reconnects.

On non-Darwin hosts the existing `fleet` commands stay available. Managed
tunnel pause/resume explain that launchd supervision is macOS-only. `fleet
doctor HOST` still checks SSH when this machine has no managed mappings.

Home Manager also writes direct plain-shell and `tm-` SSH aliases for every
remote inventory host. For example, `ssh kim` opens a plain shell while
`ssh tm-kim` attaches to tmux. The old `main-pc` name remains a migration alias.

All records in `lib/hosts.nix` are Fleet members. Home Manager omits the local
machine from its SSH blocks, so each machine receives aliases for every peer
without a directional allow-list.

## Herdr machines

Herdr 0.9.0 is the native session UI: Local plus saved SSH machines in one
window. Run `h` (or `herdr`) and pick a machine in the sidebar. Home Manager
installs the `herdr` package through `users/maxpw/modules/agent-tools.nix`. It
does not generate a machine catalog from the fleet inventory. Saved machines,
selection, and other client state stay in Herdr's own files. Add or edit
machines with Herdr itself, including `herdr machine ...` or the sidebar.

A saved profile is one session on a host, not every session. Remote agents show
up in Herdr's combined list, and a disconnect retries without stopping remote
processes.

Check `type -a herdr` if an older `~/.local/bin/herdr` is shadowing the Nix
package. Saved connections never install or replace servers in the background.
An old server may show Attention; run `herdr --remote <host> --session default`
interactively when you are ready to follow its setup prompts. Replacing a
pre-v0.9 server can stop its panes and agents. Finish or save work first, and
do not approve a replacement just because the client and server versions differ.

See the [v0.9.0 release notes](https://github.com/herdrdev/herdr/releases/tag/v0.9.0)
and [machine guide](https://herdr.dev/docs/connecting-machines/).

## Agent Fleet Contract

Home Manager generates `~/.config/fleet/FLEET.md` from the same `hosts`
records in `lib/hosts.nix` that drive system outputs, SSH aliases, and
`~/.config/fleet/hosts.json`; do not edit
the generated file directly.

Capability fields:

- `os`: the target platform family agents should expect.
- `gui`: whether the host has a GUI/screenshot surface.
- `longRunningAgents`: whether unattended or multi-hour agent work should run
  there.
- `t3codePort`: optional T3 Code port exposed through `fleet t3`.

Every new host must set `os`, `gui`, and `longRunningAgents` explicitly.

## T3 Code

`kim` runs the pinned T3 Code nightly server on loopback port `51000`.
The homelab Tailscale Serve configuration exposes it only within the tailnet at
`https://t3code.liger-shilling.ts.net`.

`users/maxpw/settings.nix` contains the shared release lock for Kim's npm server
and Joyce's Homebrew-installed desktop app. Joyce installs the exact arm64
release through a generated private Homebrew tap and pins it after Homebrew
Bundle runs. To upgrade, update both the version and DMG SHA-256 in that file,
then rebuild Joyce and Kim from the same configuration revision.

After a service start, retrieve the one-time pairing token from the user journal:

```sh
fleet run kim journalctl --user -u t3code -b -o cat --no-pager
```

In T3 Code's remote-environment flow, enter the HTTPS URL and the
printed `Token` separately. Once paired, the desktop app uses its saved session;
the token is only needed again for another client. `fleet t3 kim` remains
available as an SSH-tunnel fallback.

## Connectivity and Trust

Fleet traffic uses each host's Tailscale MagicDNS target. Full NixOS hosts
expose SSH and mosh only through `tailscale0`. NixOS-WSL disables its firewall
service, so Cuno additionally relies on the shared sshd `AllowUsers` tailnet
policy. Joyce uses Apple's launchd-managed SSH server with the same key-only,
tailnet-source policy and is reached through its Tailscale name.

`modules/fleet/ssh-access.nix` derives the same authorized identity set from
each inventory host's `client` record and installs it on every managed server.
Only public keys and stable Tailscale addresses belong in `lib/hosts.nix`; never
copy a private key into the repository or Nix store. `client = null` keeps an
unenrolled host visible while making the missing outbound identity explicit in
the generated Fleet contract.

Fleet host keys should be pinned after bootstrap. Capture the public ED25519
host key, cross-check it against `ssh-keyscan` over the trusted Tailscale path
and the key on the host itself, then add `hostKey` to the host's inventory
record. Hosts without a pinned key temporarily use `accept-new`.

## Adding Machines

Add the machine to `lib/hosts.nix`; every inventory record automatically becomes
a Fleet member. `lib/inventory.nix` derives the target, platform capabilities,
tmux path, and accent; only override normalized defaults when needed. Public
client identity is explicit: use a `client` record when enrolled or `null` while
bootstrapping. Do not add a separate connectivity flag or edit generated files.

NixOS and WSL machines import `modules/fleet/nixos.nix`, which enables Tailscale
and mosh. `modules/fleet/ssh-access.nix` owns key-only SSH hardening and tailnet
source restrictions across NixOS, WSL, and Darwin.

## Deployment Checks

After Joyce's first switch, keep the local GUI session open and verify Apple's
Remote Login service; nix-darwin uses `launchctl` because `systemsetup` requires
Full Disk Access and can otherwise report misleading state:

```sh
sudo launchctl print system/com.openssh.sshd
sudo /usr/sbin/sshd -T
sudo systemsetup -getremotelogin
```

Then connect from Kim, cross-check Joyce's ED25519 host-key fingerprint on the
Mac, and pin `hostKey` in `lib/hosts.nix`. Joyce has no LAN/localhost SSH
fallback: its `AllowUsers` policy accepts only tailnet source ranges and each
authorized credential is further restricted to its enrolled Tailscale IPv4
and IPv6 addresses.

Before applying trust changes to headless Kim, keep the current SSH session
open and confirm local-console recovery. Re-enrolling a device in Tailscale can
change its addresses; update its `client.tailscaleIps` on peers before closing
the old session.

For Cuno, follow `docs/wsl-setup.md`. The WSL VM must be running, its own
`tailscaled` must be enrolled, and its public client key must be added before
Cuno has independent outbound Fleet access.
