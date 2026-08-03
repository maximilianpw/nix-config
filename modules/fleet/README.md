# Revachol Fleet

Revachol is the name of this repo's remote development fleet. The operational
CLI remains `fleet`.

## Commands

- `fleet list` shows the declared machines and aliases.
- `fleet herdr <host> [session] [--forward <port-or-map>...]` opens the host's
  persistent, agent-aware Herdr session with optional managed project ports.
- `fleet ssh <host>` connects to `tmux new-session -A -s main` on that host.
- `fleet ssh <host> <session>` attaches to a named tmux session.
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

Use `fleet herdr <host>` from an ordinary terminal when agent work should run
on another machine. Herdr's server, panes, and agent detection then live on the
remote host; detaching or losing SSH leaves them running, and invoking the same
command reattaches. A local Herdr session wrapped around `fleet ssh` sees only
the local `ssh` process, so remote agents cannot appear in its agent menu.

Add `--forward 3000` to expose the remote loopback port on the same local port,
or `--forward 3000:5173` to map local port 3000 to remote port 5173. The option
is repeatable. Fleet establishes every forward before attaching Herdr, so the
remote app can start afterward, and removes the forwards when the local Herdr
client exits:

```sh
fleet herdr kim agents --forward 3000 --forward 5173
```

Use standalone `fleet forward` when a tunnel must remain independent of a
Herdr attachment.

`fleet ssh` remains the tmux fallback for general remote shells and tools that
do not need Herdr's agent model. Its tmux session also survives a dropped SSH
client; rerun the same command and optional session name to reattach.

Home Manager also writes direct plain-shell and `tm-` SSH aliases for every
remote inventory host. For example, `ssh kim` opens a plain shell while
`ssh tm-kim` attaches to tmux. The old `main-pc` name remains a migration alias.

All records in `lib/hosts.nix` are Fleet members. Home Manager omits the local
machine from its SSH blocks, so each machine receives aliases for every peer
without a directional allow-list.

Hosts with a declared `plannotatorPort` expose the port as an on-demand Fleet
capability. Kim uses port `19432`; attach with
`fleet herdr kim --forward 19432` before starting a remote Plannotator review,
then open `http://127.0.0.1:19432`. Standalone
`fleet forward kim 19432 19432` remains available when Herdr is not involved.
Keeping this forward opt-in avoids stale browser tabs repeatedly generating
failed-forward errors while Plannotator is not listening.

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
- `plannotatorPort`: optional loopback port available through an on-demand
  `fleet forward` tunnel.
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
