# ADR 0001: Unattended agent access on Kim

Status: accepted on 2026-10-02 (owner decision, Linear PRS-360).

This record fixes the credential scope and permitted operations for agent work
that runs on Kim without a human in the loop. It records the decision as made;
it does not reopen it. The final section lists what the decision leaves
reachable so the owner can confirm or tighten it later.

## Context

Unattended agents are scheduled or event-driven agent sessions that nobody is
watching while they run. The first such workload is the read-only morning
report (Linear PRS-361), which writes a local Markdown file and changes nothing
else. The [agent tooling backlog](../agent-tooling-backlog.md) had deferred any
scheduling until the credential and operation scope was defined.

Kim already runs everything agent-related as the personal user `maxpw`, so an
unattended session on Kim inherits that identity's existing surface:

- The T3 Code headless server is a `systemd --user` service for `maxpw`
  (`users/maxpw/modules/t3code-server.nix`), lingering is enabled so it starts
  at boot (`machines/kim.nix`), and it runs the same Claude, Codex, OpenCode,
  and Grok binaries an interactive session uses.
- The CLIProxyAPI gateway and its quota endpoint run as `maxpw`
  (`modules/cliproxyapi/nixos.nix`), and the generated client wrappers
  (`modules/cliproxyapi/home-manager.nix`) read the local API token from
  `/run/secrets/cliproxyapi-local-api-key` at runtime, so every agent CLI in
  `maxpw`'s profile can reach the billable providers.
- `maxpw` is in the `docker` group on Kim (`machines/kim.nix`) for dev
  databases and the Docker-backed homelab containers, and in `wheel`.
- Fleet SSH settings disable agent forwarding, and the sshd policy is key-only
  and tailnet-only (`modules/fleet/ssh-access.nix`), but Kim holds its own
  outbound Fleet identity.

The alternatives considered were a dedicated low-privilege user or a container
with a narrow credential allowlist. Both would require duplicating the agent
toolchain, provider access, and repository checkouts for a workload whose first
instance is read-only.

## Decision

Unattended agents on Kim run as the personal user `maxpw` with the same access
as an interactive agent session. No separate user or container is introduced.

The single exclusion is `.env` files: unattended agents must not read any file
named `.env` or matching `.env.*`.

Human approval remains required for publishing, pushing, deploying, changing
shared infrastructure or live data, and destructive operations, exactly as the
repository `AGENTS.md` and the shared policy in
`users/maxpw/agents/shared/AGENTS.md` already require for interactive sessions.
An unattended session has no human available to grant that approval, so in
practice those operations are unavailable to it.

The first unattended workload is the read-only morning report (PRS-361). It
writes a local Markdown file and changes nothing else.

## Consequences

- Nothing in the Nix configuration changes. The decision is enforced by policy
  (the shared `AGENTS.md` carries the runtime rule) rather than by filesystem
  permissions, a sandbox, or a separate identity.
- The `.env` exclusion is the only credential-shaped boundary. It covers
  project-local environment files in checkouts under `maxpw`'s home; it does
  not cover the Nix-managed secret material listed in the next section, which
  remains readable by any process running as `maxpw`.
- The authorization boundaries in `AGENTS.md` are absolute for unattended
  sessions. A workload that needs to push, deploy, or mutate live data is out
  of scope for unattended execution until this ADR is revised.
- Because `maxpw` is in the `docker` group, an unattended session is
  root-equivalent on Kim's host filesystem through the Docker socket. The
  decision accepts this; it is listed below so it can be reconsidered.
- Scheduling additional unattended workloads should cite this ADR and state
  whether the workload stays read-only. Expanding beyond read-only work is a
  change to this decision, not an application of it.

## Credential-bearing paths not excluded by this decision

This section is for confirmation. It is a factual inventory, derived from this
repository's declarations, of secret material that a process running as `maxpw`
on Kim can read and that the `.env` exclusion does not cover. It is not a list
of additional exclusions. Each line names the path and what it grants. No
secret contents were read while compiling it.

### Keys that unlock other secrets

- `~/.config/sops/age/keys.txt`: the `admin_max` age identity for
  `secrets/*.yaml` (`.sops.yaml`, `secrets/README.md`). It decrypts every
  entry in the repository's secret store, including root-only runtime secrets
  such as the Borg passphrase, Cloudflare Tunnel credentials, and the
  Vaultwarden environment.
- Docker group membership (`machines/kim.nix`): the Docker socket is
  root-equivalent on the host, so it reaches `/var/lib/sops-nix/key.txt`,
  `/etc/ssh/ssh_host_ed25519_key` (the second sops recipient), every
  root-owned file under `/run/secrets/`, `/var/lib/executor` (Executor's
  database and generated encryption keys), and all container state.
- `wheel` membership (`users/maxpw/nixos.nix`): sudo is available but requires
  the user's password, which is stored only as a hash
  (`/run/secrets/maxpw-password`), so it does not grant unattended escalation
  by itself.

### Provider and API credentials

- `/run/secrets/cliproxyapi-local-api-key` (owner `maxpw`, mode 0400): the
  bearer token every local agent wrapper uses against CLIProxyAPI on
  `127.0.0.1:8317`, which fronts the billable Codex, Claude, Grok, and Zen
  providers.
- `/run/secrets/cliproxyapi-public-api-key` (owner `maxpw`, mode 0400): the
  bearer token for `https://cliproxy.maximilian.pw/v1`, the same providers
  reachable from any network.
- `/run/secrets/rendered/cliproxyapi.conf` (owner `maxpw`, mode 0400): the
  rendered server configuration, which embeds the local API key and the
  OpenCode Zen API key in plaintext. The management key appears only as a
  bcrypt hash.
- `~/.cli-proxy-api/*.json`: CLIProxyAPI's `auth-dir`
  (`modules/cliproxyapi/config.nix`), holding the mutable provider OAuth
  tokens for the Codex, Claude, and xAI accounts. These are the upstream
  account credentials, not just gateway tokens; the quota service reads them
  directly.
- `/run/secrets/linear-api-key` (owner `maxpw`, mode 0400): read and write
  access to the Linear workspace.
- `~/.codex/auth.json`, `~/.claude/.credentials.json`, and similar per-CLI
  login files, if present: direct provider logins that bypass the gateway. The
  Nix wrappers route through CLIProxyAPI, so these exist only if a CLI was
  logged in manually.

### Source control and identity

- `/run/secrets/github-ssh-private-key` (owner `maxpw`, mode 0600): the GitHub
  authentication key `~/.ssh/config` uses for `github.com` on non-desktop
  NixOS hosts (`users/maxpw/home-manager.nix`). It can push as the owner to any
  repository the key is authorized for.
- `~/.gnupg/` with the signing key `992CF94F12CF7405147D81FD4AB37B87F45FAC60`
  (`users/maxpw/modules/git.nix`): commit and tag signing as the owner.
  `gpg-agent` caches the passphrase for one year
  (`users/maxpw/modules/gpg.nix`), so signing needs no prompt once unlocked.
- Git credential cache (`credential.helper = cache --timeout=3600`): any HTTPS
  Git credential entered interactively stays usable for an hour through the
  cache socket.
- `~/.config/gh/hosts.yml`, if present: a GitHub CLI token. `gh` is not
  installed by this configuration, so the file exists only after a manual
  install and login.

### Fleet and host access

- `~/.ssh/fleet_ed25519`: Kim's outbound Fleet identity
  (`lib/hosts.nix`, `client.identityFile`). Its public key is authorized for
  `maxpw` on every enrolled Fleet host (`modules/fleet/ssh-access.nix`), so it
  grants a `maxpw` shell on Joyce over the tailnet. Agent forwarding is
  disabled, which limits onward hops but not the direct login.
- `/run/secrets/syncthing-gui-password` (owner `maxpw`) and
  `~/.config/syncthing/` (`key.pem`, `cert.pem`, `config.xml`): the Syncthing
  GUI login and the device identity, which can add peers and share folders
  from Kim's home directory (`homelab/syncthing.nix`).
- `/run/secrets/himalaya-bridge-password` (owner `maxpw`): the Proton Bridge
  password declared in `modules/core/sops.nix`. Mail is not enabled on Kim, but
  the decrypted file is still present and user-readable there.
- `~/.local/share/atuin/key` and `~/.local/share/atuin/session`: the
  end-to-end encryption key and session token for synced shell history
  (`users/maxpw/modules/shells.nix`), which exposes the history itself.
- `~/.config/op/`, if present: the manually configured 1Password CLI account
  on the headless host. A session token exists only while signed in; the
  `op` CLI itself is installed (`programs._1password`).

### Data rather than credentials

- `~/.local/share/t3code/`: T3 Code thread history and attachments. Not a
  credential, but it contains whatever was pasted into agent sessions.
- Any repository checkout under `~`: readable in full apart from the excluded
  `.env` and `.env.*` files. Other secret-shaped files (for example `*.pem`,
  `credentials.json`, or `.envrc`) are not excluded.
