# Plannotator Inbox

Each machine has its own Inbox. Agents connect locally; replies go back to the
session that asked. The Inbox follows where the agent runs, not where its
terminal is displayed: an SSH session on Kim uses Kim's Inbox.

## Open it from Joyce

Bookmark **https://plannotator.liger-shilling.ts.net/** with Tailscale connected,
or run:

```sh
inbox             # Open Kim's stable bookmark in this machine's browser
inbox kim         # Same destination
inbox joyce       # Open Joyce's separate local Inbox, when run on Joyce
inbox local       # Open the current machine's Inbox
inbox doctor      # Check this machine without starting or changing anything
inbox doctor kim  # Run diagnostics on Kim through Fleet
```

On a headless machine `inbox kim` prints the address instead of attempting to
open a browser. No SSH command or remembered port is required for normal use
from Joyce. `inbox doctor --json` produces machine-readable results and exits
nonzero when a check fails. It checks CLI/running-server/Pi/Claude versions and
agent declarations, the redirect's local health on Kim and the stable hostname's
DNS. It does not prove browser access grants or the tools already loaded in an
agent session.

Read messages, choose answers or annotate attachments, then press **Send**.
Native Pi, Claude Code and OpenCode 2 integrations deliver replies once idle;
stdio MCP clients poll with `wait_for_reply` or read the thread later. Start new
agent sessions after upgrades, or `/reload` in Pi. Browser notifications are
opt-in through the Inbox's Settings.

## What the stable address does

Plannotator 0.28.23 only publishes its guarded UI on a node hostname plus its
recorded Inbox port. It does not directly support a Tailscale Service hostname.
The stable address is therefore an **authenticated redirect**, not a proxy:

```text
plannotator.liger-shilling.ts.net:443
  -> Tailscale Serve svc:plannotator
  -> 127.0.0.1:19013 (stateless redirect)
  -> browser redirects to https://kim.liger-shilling.ts.net:<current-port>/
```

The address bar changes after opening; bookmark the service address. The
redirect reads the registry afresh on every request and checks the running
server's identity before returning its URL, so a changed port needs no bookmark
edit. Its target must be Kim's HTTPS hostname and the live Inbox port; arbitrary
hosts, credentials, paths, queries and fragments are refused. The health probe
never follows an HTTP redirect.

Both layers enforce the configured Tailscale login allowlist. Kim is tagged and
has no implicit human owner, so `inboxTailscaleAllow` explicitly names the owner.
The redirect accepts only its service Host and Tailscale's injected identity;
unauthenticated requests and unexpected hosts fail closed. `/health` additionally
accepts direct loopback probes for homelab monitoring. It reports unavailable
when the registry/server identity or Tailscale address is invalid.

There is no remote MCP proxy: the redirect does not forward any requests, and
Plannotator's separate guarded listener refuses remote agent tools. Keep its
built-in sharing mode; never point a generic proxy at the main Inbox port.
Neither endpoint uses Funnel or opens a LAN listener.

## Nix ownership and startup

- `flake.nix` installs the locked `llm-agents` CLI and re-signs its Bun executable
  on Darwin.
- `users/maxpw/modules/plannotator.nix` installs the host-configured CLI and
  `inbox` helper, including their `~/.local/bin/` paths. The wrapper disables
  automatic agent registration and instruction-file notes. It enables native
  Tailscale sharing only on Kim, even outside a login shell.
- On Kim, `plannotator-inbox.service` and `plannotator-inbox-redirect.service`
  run in maxpw's user manager. Existing linger enables startup without a GUI
  login. The Inbox waits for Tailscale readiness and restarts after exit; the
  redirect remains available to report a temporary outage. Joyce remains
  on-demand and local-only.
- `lib/homelab-services.nix` owns the stateless redirect endpoint, named service,
  Homepage card and `/health` monitor. The existing homelab Tailscale reconciler
  keeps `svc:plannotator` instead of deleting it as an unmanaged route.
- Existing source files configure Amp, Muse and Grok's stdio servers, Claude's
  marketplace plugin and OpenCode's native plugin. Codex owns its mutable
  config: Home Manager merges only the Inbox registration using its CLI.
- Pi's package declaration belongs to `~/pi-config/settings.json`, separately
  pinned to `npm:@plannotator/pi-extension@0.28.23`. Native Pi and OpenCode tools
  are enabled by the writable Plannotator config (about 2,000 tokens/request).
- CLI/Claude/OpenCode compatibility is checked during Nix regression checks.
  `inbox doctor` also checks the separately installed Pi and Claude versions.
  Update pins together; reload sessions after updates.

## Tailscale enrollment and activation

The tailnet's service definitions and approval policy live outside this repo.
In https://login.tailscale.com/admin/services, define `plannotator` with endpoint
`tcp:443` if missing and approve Kim's host advertisement. Access grants must
allow the intended user's devices to reach `svc:plannotator` on port 443. Keep
the app's narrower owner allowlist as well; don't broaden unrelated grants.

The initial cutover installed only these packages, configs and user units,
without a full system switch. They are GC-rooted under
`~/.local/state/plannotator-*`; existing installer binaries/config links were
preserved under timestamped backup names. Normal Home Manager activation can
adopt the identical files. Apply the normal Kim rebuild before relying on the
new service across reboots: the old system-level Tailscale reconciler does not
know about `svc:plannotator` and would remove it. That rebuild also activates the
Homepage card and monitoring changes. A full Joyce rebuild incorporates the
helper into the normal Home Manager generation and updates login environment.

For a fresh host with an installer-owned `~/.local/bin/plannotator`, preserve
it under a unique backup name before activating Home Manager. Do not use the
upstream installer/uninstaller on the Nix-owned executable.

Operational checks:

```sh
inbox doctor kim
systemctl --user status plannotator-inbox plannotator-inbox-redirect
journalctl --user -u plannotator-inbox -u plannotator-inbox-redirect
curl -f http://127.0.0.1:19013/health
```

The last three commands run on Kim. From Joyce, the stable URL should return a
303 to Kim's native address, and following it should return the Inbox page.
Remote `/mcp` must never serve tools.

## Data and recovery

Messages and attachments remain writable files in `~/.plannotator/inbox/`.
The inventory's `plannotator` record describes the **stateless redirect only**;
it does not claim that Inbox history is disposable or backed up. Kim's current
Borg base paths do not cover `~/.plannotator`. A consistent backup/restore
contract for that user data remains separate work; Nix does not recreate it.
Do not restore a copied live `inbox.json` as a running process identity.

## Verification

```sh
nix build .#checks.x86_64-linux.plannotator-config-regression \
  .#checks.x86_64-linux.opencode-config-regression \
  .#checks.x86_64-linux.tailscale-serve-regression \
  .#checks.x86_64-linux.homepage-regression --no-link
```

The Inbox check exercises authentication, fixed-host redirects, stale registry
rejection, local-only health, denied MCP forwarding, version diagnostics and
non-clobbering Codex registration using disposable loopback servers and HOME.
It never starts a real Inbox, contacts Tailscale, sends a message or calls a paid
model. The other checks cover OpenCode's resolved config and declarative routing
and dashboard integration.
