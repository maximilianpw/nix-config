# Homelab MCP through Executor

Kim runs `homelab-mcp.service` on `127.0.0.1:19200/mcp`. Executor runs with
host networking on `127.0.0.1:19005`, so its container can reach that endpoint.
Cloudflare still routes `executor.maximilian.pw` to port 19005. There is no
public route or firewall opening for port 19200.

Executor v2 uses `EXECUTOR_APPS_ALLOW_PRIVATE_FETCH=true` for app tool calls.
Host-side import and OAuth requests have a separate exact-origin allowlist,
`EXECUTOR_URL_ALLOW_HTTP_ORIGINS`, containing `http://127.0.0.1:19200` and the
portfolio API origin. These controls do not replace the upstream bearer token.
Executor's account authentication and app tool policies remain responsible for
access. Only trusted users should be allowed to configure apps.

## Activation and connection

Build and activate the Kim configuration from this checkout:

```sh
make rebuild
systemctl status homelab-mcp docker-executor --no-pager
```

Sign in to `https://executor.maximilian.pw`. Add an app from the MCP URL
`http://127.0.0.1:19200/mcp`, then connect its account from the app page.
Configure bearer authentication using the value of the SOPS secret `homelab-mcp-access-token`.
The root-readable runtime file is `/run/secrets/homelab-mcp-access-token`.
Enter it only in Executor's secret field, never in a URL or a committed config.
Select the app's account links for the intended users.

Refresh tool discovery and call `media_stack_health` through Executor. Check
that Seerr, Sonarr, Radarr, Lidarr, Prowlarr and Plex all respond. Then call it
from another device using the v2 dashboard's **Connect** instructions for
`https://executor.maximilian.pw/mcp`. Devices need Executor authentication only;
the homelab bearer token stays in Executor.

The MCP exposes writes as well as reads. Writes require `confirm: true`; set
Executor policies to block or require approval for write tools as appropriate.

## Credentials and state

Systemd loads copies of the media applications' credential files at service
startup. The service runs as a dynamic user and cannot read the original files.
Restart `homelab-mcp` after rotating an upstream key. Plex currently uses a copy
of `Preferences.xml`, which includes account and certificate details; keep that
credential private. A future deployment can supply only `plex-token` instead.
Systemd 260.4 fails before launching the process when a `LoadCredential` source
path contains spaces. A root-only symlink under `/run/homelab-mcp-credentials`
provides a space-free alias for Plex's `Plex Media Server/Preferences.xml`.

The access token is encrypted in `secrets/homelab-mcp.yaml` for the existing
admin and Kim SOPS recipients. SQLite state and its encryption key live together
in `/var/lib/private/homelab-mcp`, exposed to the service as
`/var/lib/homelab-mcp`. The inventory includes them in quiesced backups.

## Actual Budget

The `actual_*` tools read and edit the Actual budget served by `actual.service`
on `127.0.0.1:19006`. The service signs in with the Actual server password from
the SOPS secret `media-mcp-actual-password` in `secrets/media-mcp.yaml`, loaded
as the `actual-password` credential. It opens the server's only budget; if more
budgets are added, set `ACTUAL_BUDGET_SYNC_ID` in the unit's environment to the
sync ID shown in Actual under Settings, Advanced. The budget copy lives in the
service's private `/tmp` and is downloaded again after every restart. Adding or
editing transactions and setting budget amounts require `confirm: true`.

After a password change in Actual, update the SOPS secret and rebuild; the unit
restarts when the secret changes.

`@actual-app/api` in the package must match `actual-server`'s version, currently
26.10.0. When `make update` moves `pkgs.unstable.actual-server`, the budget tools
fail with a migrations error until the application's `@actual-app/api` dependency
is bumped to the same version and the package is refreshed.

## Plexamp discovery

The October 3 package adds Plex music search, playlist reads, creation, renaming,
and ordered refreshes, plus Last.fm public listening-history and discovery tools.
Refreshes preserve the playlist ID and require a preview snapshot before applying.
Smart playlists are read-only. Discovery matches suggestions to existing Plex
tracks and reports missing or ambiguous matches without downloading music.

After rebuilding, refresh Executor's tool discovery. Last.fm needs an application
API key saved in this installation's encrypted connection store. Run the packaged
`homelab-mcp-admin connections set-lastfm --api-key-file /private/path/lastfm-api-key`
with access to the service's state and credentials. Set
`HOMELAB_MCP_DATA_DIRECTORY` to `/var/lib/homelab-mcp` and
`HOMELAB_MCP_CREDENTIALS_DIRECTORY` to the service's systemd credential directory.
Use the service identity and preserve state ownership; this is a dynamic-user
service, so an ordinary shell cannot access these paths. Restart the service after
saving the connection. Rebuilding alone does not configure the Last.fm key.

The T3 task `Refresh side quests` is configured for 07:45 daily in Europe/Paris,
using Last.fm user `maxpw777`. It remains disabled until the new tools are available,
the existing `side quests` playlist and music library are uniquely identified,
and a live discovery and playlist-refresh preview succeeds. Enable the existing
task after those checks. The package itself does not run a scheduler.

## Package provenance

The `homelab-mcp` flake input pins upstream release
[`v0.1.1`](https://github.com/maximilianpw/homelab-mcp/releases/tag/v0.1.1).
`flake.lock` records its exact commit and source hash, and `homelab/media-mcp.nix`
consumes the upstream `homelab-mcp` package. The source repository owns the Nix
build recipe; this repository does not vendor a source archive or duplicate it.
Database migrations and dependencies are unchanged from the previous snapshot.

The repository is private, so the input uses Git over SSH. Evaluation on a new
machine requires a GitHub SSH identity with repository access. Authentication
stays with the evaluating user, never in a Nix expression, URL credential, or
the Nix store.

The transaction-update fix uses a default import of `@actual-app/api` so Bun
reads its live `internal` getter. A namespace import captures the initial
`null` value and incorrectly reports "the Actual engine is not running" even
when other budget tools work.
The Nix package runs the TypeScript with Bun and installs production dependencies
from the frozen lockfile in a fixed-output derivation. Bun applies the
better-sqlite3 patch from `patches/` during that install; the package then
compiles the patched addon with node-gyp, because the unpatched prebuilds crash
Bun. It does not depend on the development checkout at runtime.

For an upgrade, update and verify the source repository first, bump its
application version, then publish a new release tag. The upstream README owns
its verification and release instructions. Dependency changes also require
updating the upstream dependency derivation's version and fixed-output hash.

Then change the release tag in `flake.nix` and refresh only this input:

```sh
nix flake update homelab-mcp
nix build --impure --expr \
  '(builtins.getFlake (toString ./.)).inputs.homelab-mcp.packages.x86_64-linux.homelab-mcp' \
  --no-link
nix flake check --no-build
```

Build the upstream package directly with
`nix build 'git+ssh://git@github.com/maximilianpw/homelab-mcp?ref=refs/tags/v0.1.1#homelab-mcp'`
if needed. After an explicitly authorized activation, check authenticated MCP
discovery and read-only budget access. Configuration builds do not authorize
live transaction edits.

## Recovery

Stop `homelab-mcp.service` and restore the entire archived
`/var/lib/private/homelab-mcp` directory, including `homelab-mcp.sqlite` and
`secret-key`. Restore the archived package version before upgrading its schema.
Recreate the SOPS token and restore Executor's database and encryption key as
described in `homelab-recovery.md#executor`. Restart the services and verify an
authenticated `media_stack_health` call through Executor. Do not restore only
the SQLite database without its encryption key.
