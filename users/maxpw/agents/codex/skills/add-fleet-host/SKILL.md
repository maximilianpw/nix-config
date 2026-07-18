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
- `lib/fleet.nix`
- `modules/fleet/home-manager.nix`
- `users/maxpw/cmux/sidebars/fleet.swift.tpl`
- `users/maxpw/modules/tmux.nix`

Run `fleet list` if available to see current host names and aliases.

## Host Facts

Collect or infer these values before editing:

- Inventory key, for example `main-pc` or `build-box`.
- SSH target, preferably Tailscale MagicDNS, as `hostName`.
- Remote login `user`.
- Short `aliases` for shells and agents.
- `role`, such as `nixos-desktop`, `darwin-brain`, `linux-builder`, or `agent-runner`.
- `os`: use `nixos`, `darwin`, `linux`, or `wsl`.
- `gui`: whether screenshots/GUI work are possible.
- `longRunningAgents`: set `true` only for machines intended for unattended or multi-hour agent work.
- `tmuxCommand`: absolute path is best for NixOS or nix-darwin hosts.
- Optional `hostKey`: pin only after cross-checking the host's real ED25519 public key.
- Optional `port` and `t3codePort`.
- Sidebar accent color and SF Symbol icon.

If key facts are missing, ask for them. Do not guess `longRunningAgents = true`.

## Implementation

1. Add the host to `lib/hosts.nix` and set its nested `fleet` record.
2. Use `hostName`, `user`, `aliases`, `tmuxSession = "main"`, `tmuxCommand`, `role`, `os`, `gui`, and `longRunningAgents` explicitly.
3. Leave `hostKey` absent only when the key has not been verified; the generated SSH config will use `StrictHostKeyChecking = "accept-new"` until it is pinned.
4. For NixOS machines managed by this repo, confirm the machine imports `modules/fleet/nixos.nix`.
5. Add a machine button in `users/maxpw/cmux/sidebars/fleet.swift.tpl` using:

```swift
Button(action: { cmux("workspace.create", title: "HOST", initial_command: "/bin/sh -lc 'exec /etc/profiles/per-user/$(/usr/bin/id -un)/bin/fleet ssh HOST'", focus: true) }) {
  ...
}
```

6. Add a per-host color to `users/maxpw/modules/tmux.nix` only if that host uses this repo's tmux module. This controls the tmux status bar color on the target machine.
7. Do not edit generated files such as `~/.config/fleet/hosts.json`, `~/.config/fleet/FLEET.md`, or `~/.ssh/config`.

## Verification

Run the smallest relevant checks after editing:

```bash
alejandra --check lib/fleet.nix modules/fleet/home-manager.nix users/maxpw/modules/tmux.nix users/maxpw/modules/cmux.nix
git diff --check -- lib/fleet.nix modules/fleet/home-manager.nix users/maxpw/cmux/sidebars/fleet.swift.tpl users/maxpw/modules/tmux.nix users/maxpw/modules/cmux.nix
nix build --no-link '.#darwinConfigurations.macbook-pro-m1.system'
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
