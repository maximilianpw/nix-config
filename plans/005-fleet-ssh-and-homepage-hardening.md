# Plan 005: Pin fleet SSH host keys and bind homepage-dashboard to localhost

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat b31e6af..HEAD -- users/maxpw/modules/fleet.nix homelab/homepage.nix`
> ALSO: at planning time `users/maxpw/modules/fleet.nix` was UNTRACKED in git
> (new uncommitted work). If the file is missing from your checkout (e.g. you
> are in a fresh worktree created from a commit that predates it), STOP — this
> plan must run in a tree that contains the fleet module.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED (SSH lockout possible if keys are pinned wrong — mitigations below)
- **Depends on**: none (file-independent from other plans)
- **Category**: security
- **Planned at**: commit `b31e6af`, 2026-07-03

## Why this matters

Two defense-in-depth gaps:

1. Fleet SSH uses `StrictHostKeyChecking = "accept-new"` together with
   `ForwardAgent = "yes"` — the first connection to a fleet host silently
   trusts whatever key it presents, and agent forwarding means an impostor
   host contacted first gets to use the 1Password SSH agent. The fleet
   inventory is already declared in Nix, so host keys can be declared too;
   an impostor then gets rejected instead of trusted. (Agent forwarding
   itself is a documented, deliberate decision — do NOT remove it.)
2. Every homelab service binds 127.0.0.1 except homepage-dashboard, which
   listens on all interfaces — and because `tailscale0` is a trusted firewall
   interface (`modules/core/remote-dev.nix:14`), homepage is reachable from
   every tailnet device while its siblings are not. Mitigated by
   `allowedHosts` header checking, but the asymmetry should be closed.

## Current state

- `users/maxpw/modules/fleet.nix:10-29` — the inventory:
  ```nix
  fleetHosts = {
    main-pc = {
      hostName = "main-pc";
      user = "maxpw";
      aliases = ["main" "desktop"];
      ...
    };
    macbook-pro-m1 = {
      hostName = "macbook-pro-m1";
      user = "max-vev";
      aliases = ["mac" "mbp"];
      ...
    };
  };
  ```
- `users/maxpw/modules/fleet.nix:43-53` — `baseSshOptions` containing
  `ForwardAgent = "yes";` and `StrictHostKeyChecking = "accept-new";`. These
  options are attached to every generated matchBlock via `mkPlainBlock`
  (line 55) and `mkTmuxBlock` (line 63).
- `users/maxpw/modules/fleet.nix:249` — hosts.json export:
  `home.file.".config/fleet/hosts.json".text = builtins.toJSON fleetHosts;`
- This is a Home Manager module (not NixOS), so the NixOS-only option
  `programs.ssh.knownHosts` is unavailable — generate a dedicated
  known-hosts file with `home.file` instead.
- `homelab/homepage.nix:1-8`:
  ```nix
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;
    allowedHosts = "homelab.maximilian.pw";
    openFirewall = false;
    ...
  ```
- The nixpkgs 26.05 `homepage-dashboard` module has **no listen-address
  option** — only `listenPort` (exported as `PORT` in the unit environment;
  verified in the module source). Homepage is a Next.js standalone server,
  which binds the address given in the `HOSTNAME` environment variable.
- `homelab/cloudflared.nix` ingress reaches homepage at
  `http://127.0.0.1:8082` — localhost binding does not break the tunnel.
- Convention: alejandra formatting; comments explain constraints (see the
  existing comment style in homepage.nix lines 5, 17-18).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Eval check | `nix flake check --no-build` | exit 0 |
| Collect a host key | `ssh-keyscan -t ed25519 <hostName>` | one `<host> ssh-ed25519 AAAA...` line |
| Eval homepage env | `nix eval .#nixosConfigurations.main-pc.config.systemd.services.homepage-dashboard.environment.HOSTNAME` | `"127.0.0.1"` |
| Inspect generated ssh config (after switch) | `grep -A3 "Host main-pc" ~/.ssh/config` | shows UserKnownHostsFile + StrictHostKeyChecking yes |
| Check listener (on main-pc, after switch) | `ss -tlnp | grep 8082` | `127.0.0.1:8082`, not `*:8082` |

## Scope

**In scope** (the only files you should modify):
- `users/maxpw/modules/fleet.nix`
- `homelab/homepage.nix`

**Out of scope**:
- `ForwardAgent` — documented deliberate decision; leave it.
- `modules/core/remote-dev.nix` (`tailscale0` trusted interface) — deliberate fleet design; leave it.
- `modules/core/security.nix` and system sshd settings.
- Syncthing's `insecureSkipHostcheck` (homelab/syncthing.nix:30) — commented, deliberate, GUI is password-protected; explicitly rejected as a finding.

## Git workflow

- Branch: work directly in the current tree if fleet.nix is still uncommitted
  (an isolated worktree will not contain it). Otherwise `advisor/005-fleet-hardening`.
- Commit style: `feat: pin fleet ssh host keys` / `fix: bind homepage to localhost`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Collect the real host keys

For each fleet host (`main-pc`, `macbook-pro-m1`):

```sh
ssh-keyscan -t ed25519 main-pc
ssh-keyscan -t ed25519 macbook-pro-m1
```

Cross-check each key against the host's own record by running, on that host
(e.g. via `fleet run <host> cat /etc/ssh/ssh_host_ed25519_key.pub`), and
comparing the base64 blob. A keyscan result that doesn't match the host's own
file is a STOP condition (something is intercepting).

**Verify**: two ed25519 public keys, each matching its host's local record.

### Step 2: Declare keys in fleet.nix and pin

1. Add a `hostKey` attribute to each entry in `fleetHosts` (the full
   `ssh-ed25519 AAAA...` string, no hostname prefix).
2. Build a known-hosts file and switch pinning on. Sketch:

```nix
fleetKnownHosts = concatStringsSep "\n" (mapAttrsToList (
  _: host: "${host.hostName} ${host.hostKey}"
) (filterAttrs (_: host: host ? hostKey) fleetHosts));
```

```nix
home.file.".ssh/fleet_known_hosts".text = fleetKnownHosts;
```

3. In `baseSshOptions`, replace `StrictHostKeyChecking = "accept-new";` with:

```nix
StrictHostKeyChecking = "yes";
UserKnownHostsFile = "${config.home.homeDirectory}/.ssh/fleet_known_hosts ${config.home.homeDirectory}/.ssh/known_hosts";
```

(`config` is already in the module args — see line 47 which uses
`config.home.homeDirectory`.) Run `alejandra users/maxpw/modules/fleet.nix`.

**Verify**: `nix flake check --no-build` → exit 0.

### Step 3: Bind homepage to localhost

In `homelab/homepage.nix`, alongside the `services.homepage-dashboard` block
(same file, top level of the returned attrset), add:

```nix
# The nixpkgs module exposes no listen-address option; homepage is a
# Next.js standalone server and binds the address in $HOSTNAME.
systemd.services.homepage-dashboard.environment.HOSTNAME = "127.0.0.1";
```

**Verify**:
`nix eval .#nixosConfigurations.main-pc.config.systemd.services.homepage-dashboard.environment.HOSTNAME`
→ `"127.0.0.1"`.

### Step 4: Apply and functionally verify

Apply on the machine you are on (`make rebuild`), and on main-pc for the
homepage change (directly or via `fleet run main-pc`):

1. SSH pinning: `ssh main-pc true` → succeeds silently. Then prove the pin
   bites: `ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=yes main-pc true`
   → fails with "No ED25519 host key is known" (expected failure = gate works).
2. Homepage (on main-pc): `ss -tlnp | grep 8082` → shows `127.0.0.1:8082`.
   If it still shows `*:8082` or `0.0.0.0:8082`, the HOSTNAME env is not
   honored by this homepage version → STOP condition 3.
3. Tunnel still works: `curl -s -o /dev/null -w '%{http_code}' https://homelab.maximilian.pw` → `200` (or `302`).

## Test plan

No test framework; Step 4 is the functional test. Record its three outputs in
the completion report.

## Done criteria

- [ ] `nix flake check --no-build` → exit 0
- [ ] Every `fleetHosts` entry has a `hostKey`; `baseSshOptions` has `StrictHostKeyChecking = "yes"` and no `accept-new` remains (`grep -c accept-new users/maxpw/modules/fleet.nix` → 0)
- [ ] `~/.ssh/fleet_known_hosts` exists after switch and contains one line per fleet host
- [ ] `ssh main-pc true` and `ssh macbook-pro-m1 true` (from the other host) exit 0
- [ ] On main-pc: `ss -tlnp | grep 8082` shows only 127.0.0.1; tunnel URL still serves
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- `users/maxpw/modules/fleet.nix` does not exist in your checkout (untracked
  at planning time — see drift check note).
- A `ssh-keyscan` result does not match the key read from the host itself.
- A fleet host is unreachable during Step 1 — do not pin a guessed key.
- After Step 4.2 homepage still binds all interfaces — revert nothing, report;
  fallback options (nginx front, firewall interface rule) are an operator
  decision.
- SSH to any fleet host stops working after the switch and one config
  re-check doesn't fix it — roll back (`make rollback` or previous
  generation) and report.

## Maintenance notes

- Adding a fleet host now requires capturing its host key at enrollment time
  — update `docs/remote-dev-fleet.md` with a one-liner
  (`ssh-keyscan -t ed25519 <host>`) as part of this change or as follow-up.
- Host key rotation (OS reinstall) will hard-fail SSH until `hostKey` is
  updated — that is the feature, but it will surprise future-you; the error
  message names the file to update.
- Reviewer: confirm no secret material is in the diff — host *public* keys
  are safe to commit; private keys must never appear.
