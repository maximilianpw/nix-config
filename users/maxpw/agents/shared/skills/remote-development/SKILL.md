---
name: remote-development
description: Operate trusted remote development machines through the Fleet CLI. Use when selecting a remote host, running remote checks or agents, opening SSH/tmux sessions, forwarding ports, or connecting to T3 Code.
---

# Remote Development

## Start Here

1. Run `fleet list`.
2. Read `~/.config/fleet/FLEET.md` completely. It is the authoritative generated contract for available hosts, aliases, capabilities, and placement rules.
3. Select a host based on the declared OS, role, GUI availability, enrollment, and `longRunningAgents` capability. Do not assume host capabilities from memory.

## Operations

- Use `fleet run <host> <command...>` for non-interactive checks.
- Use `fleet ssh <host> [session] [--forward <port-or-map>...]` for persistent
  remote work and project ports. The remote tmux session survives disconnects;
  a port maps to itself and `local:remote` remaps it.
- Use `fleet shell <host>` for a plain interactive shell.
- Use `fleet forward <host> <local-port> <remote-port> [remote-host]` for local port forwarding.
- Use `fleet forward list` to inspect forwards and `fleet forward delete <pid>` to stop them.
- Use `fleet t3 <host> [local-port]` when the selected host declares T3 Code support.

Prefer non-interactive `fleet run` for finite verification. Keep Herdr local
and run `fleet ssh` inside a local pane for interactive or long-running remote
work. Herdr sees only the SSH process, so remote agents do not appear in its
agent menu; tmux provides remote persistence instead. Prefer `fleet ssh`
`--forward` for project ports that should share the attachment lifecycle; use
standalone `fleet forward` for independent tunnels.

## Safety

- Treat `~/.config/fleet/FLEET.md`, `~/.config/fleet/hosts.json`, and generated SSH configuration as read-only.
- Run unattended or multi-hour work only on hosts declaring `longRunningAgents = true`.
- Do not rely on forwarded SSH credentials for scheduled or unattended work.
- Never copy private SSH keys into a repository, prompt, log, or Nix store.
- If the task changes fleet inventory or trust, follow the repository's dedicated host-management skill or read `modules/fleet/README.md` before editing.
