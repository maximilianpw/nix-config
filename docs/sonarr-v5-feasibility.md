# Sonarr v5 feasibility on Kim

## Decision

**Feasible to package and trial; not yet verified safe for production.** The
candidate reviewed is upstream `v5.0.0.2668`, explicitly marked prerelease.
This assessment does not authorize activation, a live migration, or a restore.

## Current configuration

Local evaluation of `nixosConfigurations.kim.config.custom.backup.applicationVersions`
reports Sonarr `4.0.19.2979`. This is the configured version, not a measurement
of the running service. The locked unstable package is `4.0.20.3014`, not v5.
The locked unstable package set provides .NET SDK `10.0.401`.

`homelab/media/host-services.nix` uses the native NixOS Sonarr service with
loopback binding, port 8989, and group `media`. The imported NixOS module exposes
`services.sonarr.package` and launches the chosen executable with `-nobrowser`
and `-data=<dataDir>`. A dedicated package can therefore replace Sonarr without
moving it into Docker or redesigning the downloader containers.

The current package is a source build targeting .NET 8 with v4 compatibility
patches, fixed NuGet dependencies, a fixed Yarn cache, and a frontend build
command. A v5 source package needs regenerated dependency hashes, .NET 10,
reviewed patch handling, and an updated frontend build invocation. Merely
changing the version/hash is insufficient. V5 still uses Yarn 1, but its
`build` script is now `vite build`.

Sources:

- [NixOS Sonarr module](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/services/misc/servarr/sonarr.nix)
  (local locked copy inspected as the authoritative configuration).
- [Sonarr v5 package.json](https://github.com/Sonarr/Sonarr/blob/v5.0.0.2668/package.json).
- [V5 initial release notes](https://github.com/Sonarr/Sonarr/releases/tag/v5.0.0.2569)
  include .NET 10, UI/API work, removal of Basic Auth, and OIDC support.
- [Candidate release](https://github.com/Sonarr/Sonarr/releases/tag/v5.0.0.2668)
  also publishes an official Linux x64 binary. Wrapping that binary is an
  alternative to a source build, but would still need Nix runtime patching and
  separate build/startup verification.

## Integration outlook

V5 does **not** simply remove API v3. Its startup registers both V3 and V5
controller assemblies, API-key authentication, and both command routes.
Its V3 series controller remains present. This is favorable compatibility
evidence, not proof that every client workflow still works.

| Component | Evidence / remaining gate |
| --- | --- |
| Prowlarr 2.6.5.5623 | Its Sonarr proxy explicitly uses `/api/v3` and checks a minimum version of 3.0.5.0, not a v4 upper bound. Indexer sync still needs a disposable integration test. |
| Seerr 3.2.0 | Source uses API-key authentication and familiar series, quality-profile, root-folder, queue, and command operations. Request creation, season monitoring, and availability sync need testing. |
| Recyclarr 8.6.0 | Exact-version v5 support not established. Verify a preview against an isolated instance, then sync only disposable profiles; v5 changes quality-profile size handling. |
| Bazarr 1.6.0 | Exact-version v5 support not established. Verify series/episode discovery and subtitle association against isolated state. |
| Unpackerr 0.15.2 | Exact-version v5 support not established. Verify queue discovery and extraction behavior using disposable files. |
| Media MCP | `homelab/media-mcp.nix` consumes the Sonarr config credential. Check status, search, and library calls in isolation; do not assume retained V3 routes prove tool compatibility. |
| qBittorrent / SABnzbd | Existing host-loopback proxies and paths need no architectural change. Test connection settings and a disposable import before acceptance. |

Primary integration sources:

- [V5 startup and controller registration](https://github.com/Sonarr/Sonarr/blob/v5.0.0.2668/src/NzbDrone.Host/Startup.cs).
- [V5's retained V3 series controller](https://github.com/Sonarr/Sonarr/blob/v5.0.0.2668/src/Sonarr.Api.V3/Series/SeriesController.cs).
- [Pinned Prowlarr Sonarr proxy](https://github.com/Prowlarr/Prowlarr/blob/v2.6.5.5623/src/NzbDrone.Core/Applications/Sonarr/SonarrV3Proxy.cs).
- [Pinned Seerr Sonarr client](https://github.com/seerr-team/seerr/blob/v3.2.0/server/api/servarr/sonarr.ts)
  and [shared client](https://github.com/seerr-team/seerr/blob/v3.2.0/server/api/servarr/base.ts).

## Safe implementation sequence

1. Add a dedicated pinned Sonarr v5 package; preserve the standard v4 package
   as the fallback. Select v5 only for Kim's Sonarr service. Do not update the
   entire flake or the rest of the Arr stack just to obtain this prerelease.
2. Build the package and evaluate the service definition without activating it.
   Verify startup under equivalent service hardening with disposable state,
   loopback-only ingress, and a different port.
3. Test API v3 operations and the integrations above using disposable client
   configurations and fixture media. Prevent the trial from contacting real
   downloaders, indexers, notification destinations, or production libraries.
   If testing a copy of real state is later authorized, isolate networking
   **before first start**: copied state can immediately run scheduled work.
4. Before any production change, inspect the running version and authentication
   method. Resolve Basic Auth use, verify browser login through tailnet ingress,
   and verify API-key clients independently.
5. With explicit activation authorization, stop Sonarr and preserve a complete,
   consistent pre-upgrade copy of `/var/lib/sonarr/.config/NzbDrone`, including
   databases, config, and ownership. Retain it outside Git and the Nix store,
   with the old package/system revision and an off-host copy. Follow
   [media recovery](media-stack.md#recovery) and the
   [homelab recovery rules](homelab-recovery.md).
6. Activate in a maintenance window, then verify browser login, existing
   series/history/profiles, indexer sync, requests, subtitles, profile sync,
   download-client tests, and a controlled import before resuming automation.

**Rollback must include pre-upgrade application state if migrations occurred.**
V5 initializes/migrates its database during startup, before serving requests.
A NixOS generation rollback only changes binaries; do not assume v4 can safely
open state already touched by v5. Keep the candidate stopped and restore the
matching old state/package using the runbook's staging rules.

## Verification performed and limits

Performed local read-only Nix evaluation, inspected the locked package/module,
reviewed repository service/recovery wiring, and inspected upstream release and
source evidence. No package was built, no trial instance was started, no live
state or secrets were read, and no end-to-end integration or migration test was
performed. Only this assessment document was added.
