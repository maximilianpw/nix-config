# Remote Dev Fleet

This repo declares the SSH/tmux workflow used for local and mesh-networked
development machines.

## Commands

- `fleet list` shows the declared machines and aliases.
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

Home Manager also writes direct SSH aliases:

- `ssh main-pc`, `ssh main`, `ssh desktop` are plain SSH aliases.
- `ssh tm-main-pc`, `ssh tm-main`, `ssh tm-desktop` attach to tmux immediately.

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

Every new host must set `os`, `gui`, and `longRunningAgents` explicitly.

## Adding Machines

Add the machine to `lib/hosts.nix` and set its nested `fleet` record. Prefer the
machine's Tailscale MagicDNS name as `hostName`, set the remote login `user`,
and add short aliases you want agents and shells to use. Set `fleet = null` for
systems that are not SSH fleet targets.

Fleet host keys are pinned. Capture the public ED25519 key from the host,
cross-check it against `ssh-keyscan` over the trusted Tailscale path and an
existing known-hosts record, then add the public key to `fleet.hostKey`. Never
copy an SSH private key into the repository.

Full NixOS machines import `modules/fleet/nixos.nix`, which enables
Tailscale and mosh while keeping SSH hardening in `modules/core/security.nix`.
