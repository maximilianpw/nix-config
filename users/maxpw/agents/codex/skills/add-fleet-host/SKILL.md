---
name: add-fleet-host
description: Add a trusted SSH/tmux development machine to this nix-config fleet. Use when adding, changing, or reviewing hosts for `fleet ssh`, `fleet run`, cmux machine launchers, SSH aliases, per-host tmux colors, Tailscale/MagicDNS targets, or long-running agent placement.
---

# Add Fleet Host

## Overview

Use this workflow to add one trusted machine to the declarative fleet without editing generated files or weakening SSH safety.

## Read First

Read these files before making changes:

- `modules/fleet/README.md`
- `lib/hosts.nix`
- `lib/inventory.nix`
- `lib/fleet.nix`
- `modules/fleet/home-manager.nix`
- `modules/fleet/ssh-access.nix`

Run `fleet list` if available to see current host names and aliases.

## Host Facts

Collect or infer these values before editing:

- Inventory key, for example `kim` or `build-box`.
- SSH target, preferably Tailscale MagicDNS, as `hostName`.
- Remote login `user`.
- Short `aliases` for shells and agents.
- `role`, such as `nixos-desktop`, `darwin-brain`, `linux-builder`, or `agent-runner`.
- Platform flags (`darwin`, `wsl`, `linuxDesktop`); normalized `os` and `gui` values are derived.
- `longRunningAgents`: set `true` only for machines intended for unattended or multi-hour agent work.
- Optional `tmuxCommand` override; the normalized inventory derives the standard NixOS/nix-darwin path.
- Optional `hostKey`: pin only after cross-checking the host's real ED25519 public key.
- Optional `port` and `t3codePort`.
- Accent color used by tmux and the generated cmux Fleet sidebar.
- The host's public client key and stable Tailscale IPv4/IPv6 addresses; never collect a private key.

If key facts are missing, ask for them. Do not guess `longRunningAgents = true`.

## Implementation

1. Add the host to `lib/hosts.nix`. Every inventory host is automatically a Fleet member; do not add a connectivity flag or nested Fleet record.
2. Set the platform flags, `user`, `role`, `longRunningAgents`, and `client` explicitly. The normalized inventory derives `os`, `gui`, `accent`, `tmuxCommand`, and the default `hostName`.
3. Add optional `aliases`, target override, ports, host key, or presentation overrides directly to the host record only when they differ from defaults.
4. Leave `hostKey` absent only while bootstrapping; generated SSH config uses `StrictHostKeyChecking = "accept-new"` until it is pinned.
5. Generate `~/.ssh/fleet_ed25519` on non-Darwin clients (or use the 1Password SSH agent on Darwin), then add only the public key, identity selector, and stable Tailscale IPv4/IPv6 addresses to the host's `client` record. `modules/fleet/ssh-access.nix` derives and distributes the restricted trust set.
6. For NixOS and WSL machines, confirm the system imports `modules/fleet/nixos.nix`; all platforms import `modules/fleet/ssh-access.nix` through their user OS module.
7. The cmux machine buttons and tmux accent are generated from inventory data. Do not add per-host code to the sidebar or tmux module.
8. Do not edit generated files such as `~/.config/fleet/hosts.json`, `~/.config/fleet/FLEET.md`, or `~/.ssh/config`.

## Verification

Run the smallest relevant checks after editing:

```bash
alejandra --check lib/hosts.nix lib/inventory.nix lib/fleet.nix flake.nix modules/fleet users/maxpw/modules/cmux.nix users/maxpw/modules/tmux.nix
git diff --check -- lib/fleet.nix modules/fleet/home-manager.nix users/maxpw/cmux/sidebars/fleet.swift.tpl users/maxpw/modules/tmux.nix users/maxpw/modules/cmux.nix
nix build --no-link '.#darwinConfigurations.joyce.system'
```

After applying the rebuild, verify the live workflow:

```bash
fleet list
fleet run HOST true
fleet ssh HOST
cmux reload-config
cmux sidebar reload fleet
cmux sidebar select fleet
```

If `fleet run HOST true` fails with `Permission denied (publickey)`, diagnose SSH authorization on the remote host before changing the local fleet config.
