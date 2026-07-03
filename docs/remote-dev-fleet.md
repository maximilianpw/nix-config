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
  local forward.
- `fleet t3 <host> [local-port]` forwards the remote T3 Code server on port
  `51000`.

Home Manager also writes direct SSH aliases:

- `ssh main-pc`, `ssh main`, `ssh desktop` are plain SSH aliases.
- `ssh tm-main-pc`, `ssh tm-main`, `ssh tm-desktop` attach to tmux immediately.

## Adding Machines

Add new trusted machines to `fleetHosts` in
`users/maxpw/modules/fleet.nix`. Prefer the machine's Tailscale MagicDNS name as
`hostName`, set the remote login `user`, and add short aliases you want agents
and shells to use.

Full NixOS machines import `modules/core/remote-dev.nix`, which enables
Tailscale and mosh while keeping SSH hardening in `modules/core/security.nix`.
