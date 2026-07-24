# Revachol Fleet

Revachol is the name of this repo's remote development fleet. The operational
CLI remains `fleet`.

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
- `fleet t3 <host> [local-port]` forwards a host's declared T3 Code server port.

Home Manager also writes direct SSH aliases:

- `ssh kim`, `ssh main`, `ssh desktop` are plain SSH aliases.
- `ssh tm-kim`, `ssh tm-main`, `ssh tm-desktop` attach to tmux immediately.
- The old `main-pc` name remains a migration alias.

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

`kim` runs the pinned stable T3 Code server on loopback port `51000`.
The homelab Tailscale Serve configuration exposes it only within the tailnet at
`https://t3code.tail7161c3.ts.net`.

After a service start, retrieve the one-time pairing token from the user journal:

```sh
fleet run kim journalctl --user -u t3code -b -o cat --no-pager
```

In T3 Code's remote-environment flow, enter the HTTPS URL and the
printed `Token` separately. Once paired, the desktop app uses its saved session;
the token is only needed again for another client. `fleet t3 kim` remains
available as an SSH-tunnel fallback.

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
