# Media companions

Kim's configuration adds Recyclarr, Unpackerr, Maintainerr, Tdarr, Tautulli,
Kometa, cross-seed, and autobrr to the [existing media stack](media-stack.md).
Chaptarr is excluded. The selection uses a minimum of 1,000 GitHub stars;
see the dated [maintenance research](media-stack-additions-research.md).

The owning module is `homelab/media/companions.nix`. Service endpoints, backup
state, and recovery contracts live in `lib/homelab-services.nix`. Native packages
come from the locked nixpkgs input. Maintainerr 3.29.0, Tdarr 2.92.01, and Kometa
2.5.1 use immutable upstream OCI image digests. Building or evaluating this
configuration does not activate it.

## Access and setup

| Component | Address or unit | Initial behavior |
| --- | --- | --- |
| Recyclarr | `recyclarr.timer`, `recyclarr.service` | Daily quality-profile sync |
| Unpackerr | `unpackerr.service` | Torrent extraction for Sonarr, Radarr, and Lidarr |
| autobrr | `https://autobrr.liger-shilling.ts.net` | Manager clients and HD acquisition filters configured |
| Maintainerr | `https://maintainerr.liger-shilling.ts.net` | Configure a media server and rules |
| Tautulli | `https://tautulli.liger-shilling.ts.net` | Connect the intended Plex account |
| Tdarr | `https://tdarr.liger-shilling.ts.net` | Worker paused; no jobs run automatically |
| Kometa | `docker-kometa.service` | Genre/decade collections; daily at 03:15 |
| cross-seed | `cross-seed.service`, local API port 2468 | Waits for `/var/lib/cross-seed/integrations.json` |

Dashboard listeners are private. Maintainerr and Kometa use host networking to
reach the existing loopback service APIs. Maintainerr binds its own dashboard to
127.0.0.1. Tdarr's dashboard is published on host loopback only; its worker API
is not published. Kometa is a scheduler and cross-seed 6.x has no dashboard.

### Tailscale enrollment

The inventory already feeds these four dashboards into Kim's Tailscale Serve
configuration. The tailnet's service definitions, host approval, and access
policy are managed outside this repository.

In the [Tailscale Services admin page](https://login.tailscale.com/admin/services),
define any missing services named `autobrr`, `maintainerr`, `tautulli`, and
`tdarr`, each with endpoint `tcp:443`. After deployment, approve Kim's host
advertisement for each service unless the existing auto-approval policy covers
Kim's `tag:homelab` identity. Ensure access grants permit the intended users or
devices to reach those `svc:` destinations on port 443. The backend ports in
the module remain loopback-only. See the [Tailscale Services guide](https://tailscale.com/kb/1552/tailscale-services).

On 2026-09-30, the four service definitions were created in the Tailscale admin
console and verified with endpoint `tcp:443` and their expected MagicDNS names.
The user subsequently activated Kim's configuration and approved all four
host advertisements. The admin console now reports one online host for each
service. Access policy and auto-approval rules were not changed.

### Recyclarr and Unpackerr

Both load existing Servarr `config.xml` files through systemd `LoadCredential`.
`scripts/media-manager-api-env.py` validates the API keys and passes them only
in the child process environment. No key is written into Git, the Nix store,
or process arguments. Restarting a service takes a fresh credential snapshot.

Recyclarr creates separately named `TRaSH WEB-1080p` and `TRaSH HD Bluray + WEB`
profiles, using the official guide IDs. The instances are named `kim-sonarr`
and `kim-radarr`; Recyclarr requires names to be unique across service types.
The 8.6.0 package has a small progress-display patch so syncs work with
redirected output and systemd's zero-height console. It also synchronizes
recommended size definitions and the profiles' default custom formats. Select these profiles
explicitly in Sonarr/Radarr and Seerr when desired. Existing titles are not
reassigned to them. The Radarr guide profile can include 720p and 1080p; it does
not introduce a 4K/remux profile. Profile assignments remain an operator choice.

Unpackerr processes only torrent queue entries, preserves original archives,
and cleans up its extracted files after successful import. SABnzbd continues
to unpack Usenet downloads. Its only writable media paths are the two torrent
trees. It cannot rewrite the library through its filesystem permissions.

### autobrr

Its session secret is generated once into `/var/lib/autobrr-session/secret`,
with root-only permissions, and included in backups. Account, tracker, filter,
and client settings remain in `/var/lib/private/autobrr`.

Prefer actions that send releases to Sonarr, Radarr, or Lidarr at their existing
loopback addresses so those managers still apply monitoring and quality rules.
The qBittorrent WebUI is at `http://127.0.0.1:18080`. No tracker filters or
automatic downloads are configured by this module. The initial application
setup connects Sonarr, Radarr, Lidarr, and qBittorrent. Its `maxpw` account
login is saved in `/home/maxpw/.local/state/media-companions/autobrr-login.json`
with mode 0600; read it in a private terminal and change the password in autobrr.

### Maintainerr and Tautulli

Connect Maintainerr to either Plex at `http://127.0.0.1:32400` or Jellyfin at
`http://127.0.0.1:8096`, and configure its manager and Seerr connections in the
dashboard. This is one instance; managing both media servers independently
requires another instance with separate state. The user chose Plex only;
the initial setup connects Plex, Sonarr, Radarr, Tautulli, and Seerr. Begin with
collections and review the matches before enabling deletion actions. No rules are provisioned.

Tautulli connects to Plex at `http://127.0.0.1:32400`. Its account token and
watch history stay in `/var/lib/tautulli`. Tautulli's supported environment
setting enforces the loopback listener without rewriting its configuration.

### Tdarr

The initial application setup creates Movies, TV Shows, Anime, Movies - LaCie,
and TV Shows - LaCie libraries. Each has transcoding disabled, health checks
enabled, and automatic scans disabled. All worker counts remain zero.

The container sees only the two library trees and its transcode cache at
`/srv/media/.tdarr-cache`. Paths inside the container match the host paths.
The Radeon render device is available. No processing jobs or transcoding flows
are created, and the internal node starts paused with all worker counts at zero.

Run a manual library scan and review health-check settings before choosing a
transcoding flow.
Unpause the node and choose worker counts in the dashboard when ready. The
declarative startup values reapply on restart, so change them in the module
when processing should persist across restarts. The cache stays on the NVMe;
it and downloaded media are outside the backed-up control state.

Unpackerr, cross-seed, and Tdarr require both media mounts and stop when the
secondary disk is unmounted. They cannot create directories beneath its hidden
mountpoint.

### Kometa

Install the private configuration at `/var/lib/kometa/config.yml`, owned by
`kometa:media` with mode 0600. Use the [upstream configuration reference](https://kometa.wiki/en/latest/config/overview/)
for Plex/TMDb credentials, library names, and collection definitions. Plex is
reachable at `http://127.0.0.1:32400`. Keep credentials in private mutable state
or encrypted sops provisioning; never add them to Nix expressions or Git.

Start `docker-kometa.service` only after reviewing that configuration. It then
runs its configured collections daily at 03:15 in Kim's timezone. It has no
library filesystem mount, so all library updates use Plex's API.

On 2026-10-01, the user ran the privileged setup helper after the supplied
TMDb key passed its authentication check. The private configuration is
installed with mode 0600 and owner `kometa:media`. It connects to Movies,
Anime, and TV Shows using only Plex/TMDb, with genre and decade collection
defaults. There are no overlays or manager acquisition connections. The
collection minimum is two items; collection deletion and Plex trash/bundle
cleanup are disabled.

The initial run completed with exit code zero and no error/critical log
entries. Plex now reports seven collections in Movies and 20 in TV Shows.
Anime has zero library items, so its dynamic collections were skipped.
The daily service and container are running with `KOMETA_TIMES=03:15` in
Europe/Paris. Live checks confirmed the collection counts, private config
permissions, and disabled acquisition/cleanup settings. The temporary TMDb
key file and one-time helper were removed after verification; credentials
remain in the backed-up private Kometa configuration.

The configuration renderer passed the installed Kometa 2.5.1 JSON Schema
and YAML parser checks. The wizard passed Bash syntax validation. A sanitized
setup report and initial-run log are retained with mode 0600 under
`/home/maxpw/.local/state/media-companions/`.

### cross-seed

Install a private JSON file at `/var/lib/cross-seed/integrations.json`, mode
0600 and owned by root. It should contain only the `torznab` indexer URLs and
`torrentClients` connection URLs required by [cross-seed 6.x](https://www.cross-seed.org/docs/basics/options).
Use the Prowlarr indexer's Torznab URL with its API key and a qBittorrent URL
that points to `127.0.0.1:18080`. URL-encode credential characters. Do not
override the module's host, port, action, or matching settings in this file.

Start `cross-seed.service` after setting up the integrations. The default action
is `save`, so matches become `.torrent` files in `/var/lib/cross-seed/output`
without injecting downloads into qBittorrent. Do not configure that directory
as a torrent-client watch folder. Automatic injection and any required link
directories should be configured only after confirming the private tracker's
rules and a working match. No existing torrent categories are changed.

## Setup status on 2026-09-30

Maintainerr uses Plex only, with verified Sonarr, Radarr, Tautulli, and Seerr
connections. No retention or deletion rules exist. Tautulli authenticated with
Plex, refreshed its libraries, and passed an activity API check.

All four dashboards passed HTTPS checks through their Tailscale service
addresses. Tautulli's reverse-proxy setting is enabled so its redirects retain
HTTPS behind Tailscale Serve.

Recyclarr completed both the initial sync and the activated systemd service
run. Sonarr has `TRaSH WEB-1080p` with 37 custom formats; Radarr has
`TRaSH HD Bluray + WEB` with 40. No existing titles use the new profiles.
The daily timer is active.

Unpackerr is running and recognizes the existing manager queues. cross-seed
is running with the two enabled Prowlarr torrent indexers and a verified
qBittorrent login. It searches existing torrents and saves matches without
client injection. autobrr's four client connections passed their tests;
tracker feeds and acquisition filters still need operator choices.

Tdarr has five health-check libraries prepared. Automatic scans and
transcoding are disabled, and the node remains paused. Kometa is waiting
for the user's own TMDb API key and private collection configuration.

### autobrr filters configured on 2026-10-01

The application now has two enabled Generic Torznab feeds through local
Prowlarr, polling every 15 minutes. The Pirate Bay feed requests movie and TV
categories; the Nyaa.si feed requests English-translated anime. Disabled
Prowlarr indexers were not added.

| Filter | Feed | Action | Accepted releases |
| --- | --- | --- | --- |
| HD TV → Sonarr | The Pirate Bay | Kim Sonarr | 720p/1080p TV; HDTV, WEB, WEB-DL, WEBRip, BluRay |
| HD Movies → Radarr | The Pirate Bay | Kim Radarr | 720p/1080p movies; WEB, WEB-DL, WEBRip, BluRay |
| Anime HD → Sonarr | Nyaa.si | Kim Sonarr | 720p/1080p English-translated anime |
| Anime Movies HD → Radarr | Nyaa.si | Kim Radarr | 720p/1080p English-translated anime |

All four filters are enabled. Anime has no source or audio-language constraint;
English-translated Nyaa entries can contain Japanese audio with English
subtitles. The anime TV action runs first; a manager rejection allows autobrr
to try the anime movie action. Sonarr and Radarr retain their monitoring,
quality, and upgrade rules. No action sends releases directly to qBittorrent.

Both feed tests and the Sonarr/Radarr client tests passed. Before enabling the
filters, a feed refresh cached 150 Nyaa entries and 32 Pirate Bay entries with
no active acquisition filters, so the initial feed backlog did not trigger
downloads. Feed scheduling and saved filter/indexer/action connections were
verified after enabling. A new matching release is still needed to observe
the complete download and import path.

## Verification

Local configuration checks:

```bash
alejandra --check homelab/media.nix homelab/media/companions.nix lib/homelab-services.nix lib/checks.nix modules/services/backup.nix tests/media-companions-regression.nix
make lint
nix flake check --no-build
nix build .#checks.x86_64-linux.media-companions-regression --no-link
```

After an explicitly authorized deployment, check the private dashboards and
the daily Recyclarr timer. Confirm profiles load without reassigning titles,
Unpackerr recognizes the torrent queues, and the original archives remain.
Kometa and cross-seed remain skipped until their private configuration exists.
Verify Tdarr is paused before adding any library processing.

## Recovery

The inventory includes each companion's control state in the Borg manifest
and quiesces its service for the archive. The Recyclarr timer stops before its
service. Restore the archived Nix revision and native package versions or
pinned OCI image digests before restoring application state. Follow the
[homelab recovery procedure](homelab-recovery.md) using isolated restore paths.

Required state is `/var/lib/recyclarr`, `/var/lib/unpackerr`,
`/var/lib/private/autobrr`, `/var/lib/autobrr-session`, `/var/lib/cross-seed`,
`/var/lib/kometa`, `/var/lib/maintainerr`, `/var/lib/tautulli`, and
`/var/lib/tdarr`. Tdarr logs/samples and Kometa logs are excluded. Restore the
Servarr managers too, because Recyclarr and Unpackerr reuse their API keys.

Before resuming jobs, validate the private integration files, Plex/TMDb account
connections, and stored rule definitions. Keep Tdarr paused and Maintainerr
actions inactive while checking restored state. Verify Tautulli's watch history,
autobrr's filters, cross-seed's saved matches, and Recyclarr's profile state.
