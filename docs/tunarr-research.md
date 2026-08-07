# Tunarr v1.3.10 on NixOS x86_64 — research notes

Scope: what it takes to run stable Tunarr **v1.3.10** on Kim (NixOS x86_64) as a
systemd service, feeding Jellyfin. All facts below come from the official docs
site or the tagged source/release artifacts; each claim carries its source.

Verified against the `v1.3.10` git tag (`git clone --branch v1.3.10
https://github.com/chrisbenincasa/tunarr`) and the published release assets on
2026-08-06.

---

## 1. Release assets and runtime dependencies

`v1.3.10` (published 2026-07-29, `prerelease: false`) ships exactly three assets
([release API](https://api.github.com/repos/chrisbenincasa/tunarr/releases/tags/v1.3.10),
[release page](https://github.com/chrisbenincasa/tunarr/releases/tag/v1.3.10)):

| Asset | Size | sha256 |
|---|---|---|
| `tunarr-v1.3.10-linux-x64.tar.gz` | 131 202 001 | `b2cfcaad818bcd57b62437dbd6d65d5bcca0ac82b9918888330abd417c07fd5f` |
| `tunarr-v1.3.10-linux-arm64.tar.gz` | 128 836 713 | `cac5ef2935f178d7d885c582901546961a2d7364748cf2d91507e76475a100df` |
| `tunarr-v1.3.10-win-x64.exe.zip` | 128 668 389 | `c9029c1dd198ad5279e33d5609224d8b462618a0beec9f2079fdeb2ba1a3e6d2` |

The `digest` field is served directly by the GitHub releases API, so it can be
used as-is for `fetchurl`'s `hash` (after base16→SRI conversion) without a
manual `nix-prefetch`.

**Tarball contents** — verified by extracting the x64 asset. Exactly two files,
flat, no directory:

```
tunarr-v1.3.10-linux-x64     108 601 492   (the server)
meilisearch                  138 909 624   (embedded search engine)
```

This matches the archive-assembly code in
[`server/scripts/make-bin.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/scripts/make-bin.ts),
which adds only `./bin/${execName}` and `./bin/meilisearch-${arch}` (renamed to
`meilisearch`) to the archive.

**How the binary is built** — `@yao-pkg/pkg`, target `node22.20.0-linux-x64`,
with a prebuilt `better_sqlite3.node` baked into the pkg virtual filesystem
(`make-bin.ts`, `NODE_VERSION = '22.20.0'`). The published Linux tarball is the
**glibc** target, not `alpine-x64`
([`build-and-release-binary.yml`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/.github/workflows/build-and-release-binary.yml)
builds only `linux-x64`, `linux-arm64`, `win-x64`, `macos-*`).

**ELF requirements** (measured with `patchelf --print-needed`):

```
tunarr-v1.3.10-linux-x64  interp /lib64/ld-linux-x86-64.so.2
                          libdl.so.2 libstdc++.so.6 libm.so.6
                          libgcc_s.so.1 libpthread.so.0 libc.so.6
meilisearch               interp /lib64/ld-linux-x86-64.so.2
                          libgcc_s.so.1 libm.so.6 libc.so.6
```

No Node.js runtime dependency is needed because Node is statically embedded by
pkg. Do **not** run `autoPatchelfHook` or `strip` over the Tunarr executable: a
local package smoke test showed that either operation corrupts pkg's appended
payload offsets (`Pkg: Error reading from file`). Keep Tunarr byte-for-byte,
run it through Kim's nix-ld, and patch only the ordinary Meilisearch ELF.

**FFmpeg is NOT bundled.** From
[installation docs](https://tunarr.com/getting-started/installation/):

> "Tunarr currently does not provide a version of FFmpeg along with these
> binaries, so you must have your own build ready to go. We recommend using the
> pre-built FFmpeg 7.1.1 binaries provided by
> [ErsatzTV](https://github.com/ErsatzTV/ErsatzTV-ffmpeg/releases/tag/7.1.1)…
> If you are planning on using hardware acceleration, ensure that the build of
> FFmpeg you use includes the proper libraries built-in."

Docker images ship ffmpeg 7.1.1 (same page).

The **enforced minimum is 7.1**, not 7.1.1 — see
[`FfmpegVersionHealthCheck.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/services/health_checks/FfmpegVersionHealthCheck.ts):
`private static minVersion = '7.1'`, and the check only errors for major < 6 or
exactly 6.0. `nixpkgs#ffmpeg_7` is 7.1.5 and satisfies this.

Notably, upstream **ships a `shell.nix`**
([source](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/shell.nix)) that
uses `nodejs_22` plus a `fetchurl` of the ErsatzTV 7.1.1 tarball — evidence that
the Nix route is a supported-in-practice path, and a ready-made recipe if the
nixpkgs ffmpeg turns out to lack a filter Tunarr wants.

---

## 2. Config / state directory

Resolution order, from
[`server/src/util/defaults.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/util/defaults.ts):

1. `$TUNARR_DATABASE_PATH` if non-empty → used verbatim as the data directory.
2. Otherwise `<prefix>/tunarr`, where prefix is `/config` in a container,
   `$APPDATA` on Windows, `$HOME/Library/Preferences` on macOS, and
   **`$HOME/.local/share` on Linux**.

So the standalone Linux default is **`$HOME/.local/share/tunarr`**, and the
Docker default is `/config/tunarr`.

The CLI flag is `--database`, described as "Path to the database directory",
defaulting to `getDefaultDatabaseDirectory()`
([`server/src/index.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/index.ts) L66-70).
It is resolved against `process.cwd()`
([`globals.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/globals.ts):
`databaseDirectory: resolve(process.cwd(), runtimeOptions.database)`) — pass an
absolute path.

> ⚠️ **Docs/source discrepancy.** The
> [run docs table](https://tunarr.com/getting-started/run/) lists
> `TUNARR_DATABASE_NAME` as the env var paired with `--database` ("Sets the path
> where Tunarr will write its data to"). The source disagrees:
> [`util/env.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/util/env.ts)
> defines `DATABASE_LOCATION_ENV_VAR = 'TUNARR_DATABASE_PATH'`, while
> `TUNARR_DATABASE_NAME` is read separately in `getDefaultDatabaseName()` as the
> **SQLite filename** inside that directory (default `db.db`).
> **Use `--database <abs path>` and avoid both env vars** — the flag is
> unambiguous in both docs and code.

Directory contents (from the
[backup docs](https://tunarr.com/configure/system/backup/)): `db.db`,
`settings.json`, `channel-lineups/`, `images/`, `cache/`, `ms-snapshots/`,
`backups/`, `logs/`, `*.xml`, plus Meilisearch's `data.ms`.

---

## 3. Listen host / port and other options

From [`Server.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/Server.ts) L439-442:

```ts
const host = process.env[TUNARR_ENV_VARS.BIND_ADDR_ENV_VAR] ?? '0.0.0.0';
await this.app.listen({ host, ... });
```

Port precedence is documented in code as *env var → CLI argument → UI setting*
([`RunServerCommand.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/cli/RunServerCommand.ts)):

```ts
const portToUse = getNumericEnvVar(SERVER_PORT_ENV_VAR) ?? opts.port ?? portSetting;
```

Meaning: **`TUNARR_SERVER_PORT` wins over `--port`.** Default 8000.

Options relevant to a NixOS module
([run docs](https://tunarr.com/getting-started/run/),
[`util/env.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/util/env.ts)):

| Var / flag | Default | Note |
|---|---|---|
| `--database <dir>` | `$HOME/.local/share/tunarr` | data dir; absolute path |
| `TUNARR_SERVER_PORT` / `--port`, `-p` | `8000` | env beats flag |
| `TUNARR_BIND_ADDR` | `0.0.0.0` | set to `127.0.0.1` to front with Tailscale Serve |
| `TUNARR_SERVER_TRUST_PROXY` / `--trust_proxy` | `false` | Fastify `trustProxy` passthrough |
| `TUNARR_LOG_LEVEL` | `info` | overrides the UI setting |
| `LOG_DIRECTORY` | data dir | |
| `TUNARR_MEILISEARCH_PATH` | — | see below |
| `TUNARR_SEARCH_PORT` | random free port | embedded Meilisearch |
| `TUNARR_SEARCH_MAX_MEMORY`, `TUNARR_SEARCH_MAX_INDEXING_THREADS` | — / all cores | indexing limits |
| `TUNARR_DISABLE_SEARCH_SNAPSHOT_IN_BACKUP` | `false` | |
| `TUNARR_DISABLE_VAAPI_PAD` | `false` | disables `pad_vaapi`/`pad_opencl` |
| `TUNARR_DISABLE_VULKAN` | `false` | Vulkan tonemapping |
| `TUNARR_TONEMAP_ENABLED` | `false` | HDR→SDR |
| `TUNARR_SESSION_CLEANUP_DELAY_SECONDS` | `15` | |

### Meilisearch discovery — the packaging gotcha

[`MeilisearchService.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/services/MeilisearchService.ts)
L540-576 searches, for each of `meilisearch-linux-x64` and `meilisearch`:

1. the literal value of `$TUNARR_MEILISEARCH_PATH`
2. `$TUNARR_MEILISEARCH_PATH/<name>`
3. `$PWD/bin/<name>`
4. `$PWD/<name>`

and **throws** if none exist. The pkg binary does not know its own store path,
so a systemd unit must either set `TUNARR_MEILISEARCH_PATH` to the store path of
the `meilisearch` binary or set `WorkingDirectory` to a dir containing it.
Setting the env var explicitly is the robust choice. The spawned Meilisearch
runs with `cwd: databaseDirectory`, which is where `data.ms` lands.

---

## 4. Jellyfin as a media source (Tunarr → Jellyfin)

From [media sources / Jellyfin](https://tunarr.com/configure/media_sources/jellyfin/):

- Settings > Sources > "Add Jellyfin Media Source": server URL plus an **API
  key** (Jellyfin Admin Dashboard > API Keys > New API Key). Username/password
  is also accepted; Tunarr exchanges it for an API key and "does **NOT** persist
  your Jellyfin password anywhere."
- Sync is **read-only**: "Tunarr **never** mutates Jellyfin data." Libraries
  re-sync every 6 hours by default.
- For direct playback Tunarr needs "access to the underlying media files"
  through matching mounts/shares, or configured path replacements. On Kim,
  Jellyfin and Tunarr are on the same host, so the media paths already line up —
  no path replacement needed.

---

## 5. Jellyfin as a client (Tunarr → Jellyfin Live TV)

From [clients / Jellyfin](https://tunarr.com/configure/clients/jellyfin/):

- **HDHomeRun is the recommended tuner type**: "we recdommend selecting HD
  Homerun" [sic]. Tuner URL is just the Tunarr root: `http://serverIP:8000`.
- **M3U is explicitly discouraged**: users report instability "at program
  boundaries when using Tunarr as an M3U tuner" when Jellyfin isn't transcoding,
  linked to known FFmpeg issues.
- **Guide**: Add Provider → XMLTV → `http://serverIP:8000/api/xmltv.xml`.
- With multiple Tunarr instances, uncheck "Enable for all tuner devices".

Endpoints confirmed in source:

| Path | Source |
|---|---|
| `/device.xml`, `/discover.json`, `/lineup.json`, `/lineup_status.json` | [`api/hdhrApi.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/api/hdhrApi.ts) — registered at **root**, no `/api` prefix ([`Server.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/Server.ts) L386) |
| `/api/xmltv.xml`, `/api/channels.m3u` | [`api/index.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/api/index.ts) L234, L268, under `prefix: '/api'` (L387 of `Server.ts`) |

**SSDP autodiscovery**: `hdhrSettings.autoDiscoveryEnabled` defaults to `true`
and `tunerCount` to `2`
([`settingsSchemas.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/types/src/schemas/settingsSchemas.ts)
L201-202); when enabled, `Server.ts` L479-481 starts a `node-ssdp` server
advertising `/device.xml`. Jellyfin's "Detect My Devices" relies on this
(UDP 1900 multicast). Since Jellyfin and Tunarr share Kim's LAN, entering the
URL manually is simpler and avoids opening multicast — recommend manual entry
and leaving firewall alone.

---

## 6. VAAPI

From [transcode config docs](https://tunarr.com/configure/ffmpeg/transcode_config/):

- Device path setting (`vaapiDevice`): "Path to the DRI render device (default:
  `/dev/dri/renderD128`). Change this only if your device is at a non-standard
  path (e.g., `/dev/dri/renderD129` when multiple GPUs are present)."
- Driver options: `system`, `ihd`, `i965`, `radeonsi`, `nouveau` — "Leave as
  `system` unless you know you need a specific driver." Kim is AMD → `radeonsi`
  if `system` misbehaves.
- "VAAPI is the recommended choice over QSV" on Linux.
- Hardware padding uses `pad_vaapi` → `pad_opencl`; disable with
  `TUNARR_DISABLE_VAAPI_PAD=true` if artifacts appear.
- Tonemapping chain: `tonemap_vaapi` → `tonemap_opencl` → software.

Confirmed in source: the fallback when `vaapiDevice` is unset is
`/dev/dri/renderD128`
([`FfmpegStreamFactory.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/ffmpeg/FfmpegStreamFactory.ts)
L1105-1108). Device enumeration reads `/dev/dri` and collects entries starting
with `card` or `render`
([`SystemDevicesService.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/services/SystemDevicesService.ts)
L60-77); it logs an error if `/dev/dri` is absent on Linux.

**NixOS implication**: the service user needs `render` (and typically `video`)
group membership for `/dev/dri/renderD128`; a hardened unit needs
`DeviceAllow=/dev/dri/renderD128 rw` and `PrivateDevices=false`. The chosen
ffmpeg must have VAAPI enabled — `nixpkgs#ffmpeg_7` does on Linux; a
`-headless` variant should be checked before use.

---

## 7. FFmpeg path setting

`ffmpegExecutablePath` and `ffprobeExecutablePath` default to **`/usr/bin/ffmpeg`
and `/usr/bin/ffprobe`**
([`settingsSchemas.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/types/src/schemas/settingsSchemas.ts)
L89-90). Neither exists on NixOS, so on first run the FFmpeg health check errors
with "ffmpeg doesn't exist at configured path…". These are **database settings, not env vars or server flags**. They can be set
through the UI, API, or the tagged source's `tunarr settings update` CLI
([`settingsUpdateCommand.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/cli/settings/settingsUpdateCommand.ts)). The Kim unit uses the CLI before every start so immutable Nix store paths stay declarative.

---

## 8. Health endpoint

`GET /api/system/health`
([`api/systemApi.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/api/systemApi.ts)
L75-89) runs `healthCheckService.runAll()` and returns
`Record<string, HealthCheck>`. Registered checks include `FfmpegVersion`,
`HardwareAcceleration`, `FfmpegDebugLogging`, `FfmpegTranscodeDirectory`,
`MissingProgramAssociations`, and base-image checks
([`server/src/services/health_checks/`](https://github.com/chrisbenincasa/tunarr/tree/v1.3.10/server/src/services/health_checks)).

Caveats for monitoring: it always returns HTTP 200 — status lives in the JSON
body per check (`type: 'error' | 'info' | ...`). `HardwareAcceleration` returns
`info`, not `error`, when no hwaccel is found. There is no cheap liveness/ping
route; this endpoint shells out to ffmpeg, so poll it sparingly (Uptime Kuma at
minutes, not seconds), or probe `/api/xmltv.xml` for liveness.

---

## 9. Backup and recovery

Built-in scheduled backup
([backup docs](https://tunarr.com/configure/system/backup/)) — defaults:
enabled `true`, daily at 04:00, output `{data directory}/backups/`, format `tar`,
gzip `false`, keep 3. Archive contains `db.db`, `settings.json`,
`channel-lineups/`, `images/`, `cache/`, `ms-snapshots/`, `*.xml`.

> "Tunarr does not currently have a built-in restore feature. Restoration must
> be done manually." — stop server, extract, copy `db.db` + `settings.json`
> back, restart.

**Borg interaction (relevant to `modules/services/` on Kim).** The
[FAQ](https://tunarr.com/misc/faq/) warns that `data.ms` is a sparse file whose
apparent size is huge, and gives an explicit Borg recipe:

```bash
borg create --exclude '*/data.ms' /path/to/repo::backup /path/to/tunarr/.tunarr/
```

> "The Meilisearch index can be rebuilt automatically by Tunarr, so excluding
> `data.ms` from backups is generally safe, so long as the `ms-snapshots`
> directory is preserved."

→ Add `*/data.ms` to Kim's Borg excludes and back up the whole data directory;
the built-in backup job is then redundant and can be left at defaults or
disabled.

---

## 10. Upgrade behaviour

Migrations run automatically at startup, and Tunarr takes its own pre-migration
snapshot. From
[`server/src/bootstrap.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/bootstrap.ts)
L80-100: if a DB already exists it calls
`DBAccess.instance.migrateExistingDatabase(...)`; otherwise it syncs migration
tables and runs migrations. Afterwards it prunes `db-<n>.bak` files, **keeping
the newest 3**.

[`DatabaseCopyMigrator.ts`](https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/migration/db/DatabaseCopyMigrator.ts)
L32-39 does a proper SQLite online backup to a temp file, then writes
`db-<epoch_ms>.bak` next to `db.db` before copying the migrated schema in.

Consequences:

- Upgrades are one-way. There is **no downgrade path** — rolling the NixOS
  generation back does not roll back the schema; you must restore a `.bak` or a
  Borg snapshot.
- Because the `.bak` lives in the data dir alongside `db.db`, an in-place
  restore is trivial *if* the data dir survived. Take a Borg run before a
  version bump anyway.
- Meilisearch index version is checked against `serverPackage.meilisearch.version`
  (`MeilisearchService.ts` L425) — the bundled `meilisearch` binary and the
  `tunarr` binary must be upgraded **together**. Since both live in one tarball,
  package them as a single derivation; never pin them separately.

---

## Implementation recommendation

Package the release tarball as one derivation and wire a plain systemd unit into
`homelab/`. Concretely:

1. **`packages/tunarr.nix`** — package the flat official tarball without
   stripping or patching the pkg executable. Install Tunarr and Meilisearch
   together, patch only Meilisearch, and wrap Tunarr with nix-ld plus Nixpkgs
   FFmpeg on `PATH`. The deployed 8.1.2 package passed Tunarr's version and
   hardware-acceleration health checks; upstream's more conservative standalone
   recommendation remains 7.1.1.
2. **Service unit in `homelab/`**, following the existing
   `127.0.0.1`-bind-plus-Tailscale-Serve pattern:
   - `ExecStart = "${pkgs.tunarr}/bin/tunarr --database /var/lib/tunarr"`
   - `Environment`: `TUNARR_BIND_ADDR=127.0.0.1`, `TUNARR_SERVER_PORT=8000`,
     `TUNARR_MEILISEARCH_PATH=${pkgs.tunarr}/bin/meilisearch`
     ← the last one is not optional; without it startup throws.
   - `StateDirectory = "tunarr"`, `DynamicUser` **off** (needs the `render`
     group), `SupplementaryGroups = [ "render" "video" ]`,
     `DeviceAllow = [ "/dev/dri/renderD128 rw" ]`.
3. **Post-install application wiring**: let `ExecStartPre` run `tunarr settings
   update` to enforce the FFmpeg and FFprobe paths. Add the Jellyfin source with
   an API key in the UI, then in Jellyfin add
   an **HDHomeRun** tuner at `http://kim:8000` and an XMLTV provider at
   `http://kim:8000/api/xmltv.xml`. Do not use the M3U tuner.
4. **Borg**: add `*/data.ms` to the exclude list; back up `/var/lib/tunarr`.
5. **Uptime Kuma**: `GET http://127.0.0.1:8000/api/system/health` — but note it
   always returns 200, so a keyword/JSON check on `"type":"error"` is needed for
   it to mean anything.

Deliberately skipped: building Tunarr from source (pnpm + `@yao-pkg/pkg` +
downloaded prebuilt `better-sqlite3` and Meilisearch blobs — a large,
network-dependent build for zero benefit over the official binary); a NixOS
module with options for every env var (there is one consumer); declarative
management of the FFmpeg paths (they live in SQLite, not a config file).

---

## Sources

- https://github.com/chrisbenincasa/tunarr/releases/tag/v1.3.10
- https://api.github.com/repos/chrisbenincasa/tunarr/releases/tags/v1.3.10
- https://tunarr.com/getting-started/installation/
- https://tunarr.com/getting-started/run/
- https://tunarr.com/configure/media_sources/jellyfin/
- https://tunarr.com/configure/clients/jellyfin/
- https://tunarr.com/configure/ffmpeg/transcode_config/
- https://tunarr.com/configure/transcoding/
- https://tunarr.com/configure/system/backup/
- https://tunarr.com/misc/faq/
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/shell.nix
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/scripts/make-bin.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/.github/workflows/build-and-release-binary.yml
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/util/defaults.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/util/env.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/globals.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/index.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/Server.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/bootstrap.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/cli/RunServerCommand.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/cli/settings/settingsUpdateCommand.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/api/systemApi.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/api/hdhrApi.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/api/index.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/services/MeilisearchService.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/services/SystemDevicesService.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/services/HDHRService.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/services/health_checks/FfmpegVersionHealthCheck.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/services/health_checks/HardwareAccelerationHealthCheck.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/ffmpeg/FfmpegStreamFactory.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/migration/db/DatabaseCopyMigrator.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/server/src/db/DBAccess.ts
- https://github.com/chrisbenincasa/tunarr/blob/v1.3.10/types/src/schemas/settingsSchemas.ts
- https://github.com/ErsatzTV/ErsatzTV-ffmpeg/releases/tag/7.1.1
