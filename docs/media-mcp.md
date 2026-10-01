# Homelab MCP through Executor

Kim runs `homelab-mcp.service` on `127.0.0.1:19200/mcp`. Executor runs with
host networking on `127.0.0.1:19005`, so its container can reach that endpoint.
Cloudflare still routes `executor.maximilian.pw` to port 19005. There is no
public route or firewall opening for port 19200.

`EXECUTOR_ALLOW_LOCAL_NETWORK=true` permits Executor integrations to reach local
and private addresses, not only this MCP. Executor's account authentication and
integration policies remain responsible for access. Only trusted users should
be allowed to configure integrations.

## Activation and connection

Build and activate the Kim configuration from this checkout:

```sh
make rebuild
systemctl status homelab-mcp docker-executor --no-pager
```

Sign in to `https://executor.maximilian.pw`. Add an MCP integration with URL
`http://127.0.0.1:19200/mcp` and namespace `homelab`. Configure bearer
authentication using the value of the SOPS secret `homelab-mcp-access-token`.
The root-readable runtime file is `/run/secrets/homelab-mcp-access-token`.
Enter it only in Executor's secret field, never in a URL or a committed config.
Use an organization connection if other Executor users need access; a personal
connection suffices for devices signed in as the same user.

Refresh tool discovery and call `media_stack_health` through Executor. Check
that Seerr, Sonarr, Radarr, Lidarr, Prowlarr and Plex all respond. Then call it
from another device using the existing Executor MCP connection at
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

## Package provenance

`packages/homelab-mcp/source.tar.gz` is a snapshot of the working tree at
`/home/maxpw/local/homelab-mcp` on 2026-10-01, including its uncommitted persistence
work. It contains only `package.json`, `bun.lock`, `src/`, and `drizzle/`.
SHA-256: `20c96f7b23ba4eb56f80dfc51ba243c3c5f0fbd89d38363d27a110a6e6f9a2b8`.
The Nix package runs the TypeScript with Bun and installs production dependencies
from the frozen lockfile in a fixed-output derivation. It does not depend on the
development checkout at runtime.

To refresh the snapshot from the application checkout:

```sh
bun run typecheck && bun run test
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
  -czf /home/maxpw/nix-config/packages/homelab-mcp/source.tar.gz \
  package.json bun.lock src drizzle
```

Update the provenance digest and package version. If dependencies change, update
the dependency derivation's version and fixed-output hash, then rebuild and
check authenticated MCP discovery before activation.

## Recovery

Stop `homelab-mcp.service` and restore the entire archived
`/var/lib/private/homelab-mcp` directory, including `homelab-mcp.sqlite` and
`secret-key`. Restore the archived package version before upgrading its schema.
Recreate the SOPS token and restore Executor's database and encryption key as
described in `homelab-recovery.md#executor`. Restart the services and verify an
authenticated `media_stack_health` call through Executor. Do not restore only
the SQLite database without its encryption key.
