# Media stack on Kim

Kim runs Jellyfin, Tunarr, Sonarr, Radarr, Lidarr, Bazarr, Prowlarr, Seerr,
SABnzbd, and qBittorrent as one private media-automation stack. This
configuration is intended for a personal library and sources the operator is
authorized to use.
Source and indexer accounts are deliberately not declared in this repository.

## Architecture

Jellyfin, Tunarr, the Servarr managers, Prowlarr, Bazarr, and Seerr are native
NixOS services. qBittorrent and SABnzbd run in separate declarative
systemd-nspawn containers. Each downloader has its own network namespace,
Mullvad daemon, fail-closed startup gate, and host-loopback proxy:

```text
HTTPS ingress                  Kim host                    VPN containers
---------------        -------------------------    ---------------------------
Cloudflare:
  jellyfin.* --------> Jellyfin :8096
  seerr.* -----------> Seerr    :5055
Tailnet:
  tunarr.* ----------> Tunarr   :8000
  sonarr.* ----------> Sonarr   :8989
  radarr.* ----------> Radarr   :7878
  lidarr.* ----------> Lidarr   :8686
  bazarr.* ----------> Bazarr   :6767
  prowlarr.* --------> Prowlarr :9696
  qbittorrent.* -----> 127.0.0.1:18080 proxy ------> qbt:8080 --Mullvad--> peers
  sabnzbd.* ---------> 127.0.0.1:18081 proxy ------> sab:8080 --Mullvad/NNTP/TLS--> provider

LAN enp194s0 --------> Jellyfin :8096 and discovery UDP :7359
```

The host's Tailscale routing is untouched. Only the two downloader veths are
NATed to the physical interface. Mullvad's early-boot blocker, lockdown mode,
and pre-start connection gate prevent either downloader from using an
unprotected route. qBittorrent is additionally bound to Mullvad's
`wg0-mullvad` interface. Mullvad does not offer port forwarding, so this accepts
reduced inbound peer connectivity.

Downloads and the finished library share Kim's `/srv` ext4 filesystem:

```text
/srv/media/
├── torrents/
│   ├── incomplete/
│   ├── movies/
│   ├── music/
│   └── tv/
├── usenet/
│   ├── incomplete/
│   └── complete/
│       ├── movies/
│       ├── music/
│       └── tv/
└── library/
    ├── movies/
    ├── music/
    └── tv/
```

qBittorrent can see only `torrents/`. SABnzbd can see only `usenet/` plus its
existing bind-mounted `/var/lib/sabnzbd` state. Both containers use the same
stable `media` group identity as the host applications.
Sonarr, Radarr, and Lidarr can read and write the whole tree to import completed
downloads into `library/`. Bazarr can update subtitle files in
the movie and television libraries. Jellyfin can manage `library/` but cannot
see either active download tree. Tunarr has read-only access to `library/` and
cannot see either download tree. All services that touch `/srv` require the
mount and fail closed instead of writing into the root filesystem when it is
missing.

## First deployment

Apply the configuration when ready:

```nu
make rebuild
```

The initial downloader starts fail safely until both containers are separately
logged into Mullvad. Each login creates a Mullvad device, so confirm the account
has two available device slots. First open a root shell in `qbt`:

```nu
sudo nixos-container root-login qbt
```

That shell is Bash. Read the account number without placing it in shell history,
log in, and start qBittorrent:

```bash
read -rs -p "Mullvad account number: " MULLVAD_ACCOUNT; echo
mullvad account login "$MULLVAD_ACCOUNT"
unset MULLVAD_ACCOUNT
mullvad status
systemctl restart qbittorrent
systemctl status qbittorrent --no-pager
exit
```

Repeat the login in the independent SABnzbd container:

```nu
sudo nixos-container root-login sab
```

```bash
read -rs -p "Mullvad account number: " MULLVAD_ACCOUNT; echo
mullvad account login "$MULLVAD_ACCOUNT"
unset MULLVAD_ACCOUNT
mullvad status
systemctl restart sabnzbd
systemctl status sabnzbd --no-pager
exit
```

The shared pre-start policy reapplies LAN access, auto-connect, and lockdown
mode and refuses to launch either downloader unless `mullvad status` begins
with `Connected`. Failed gates retry every 30 seconds. Each Mullvad device
credential persists inside its backed-up container root; the account number is
not stored in Nix or the repository.

qBittorrent 5 prints a temporary first-run WebUI password to its journal:

```nu
sudo nixos-container run qbt -- journalctl -u qbittorrent -b --no-pager
```

Immediately sign in at `https://qbittorrent.liger-shilling.ts.net` and set a
permanent username and strong password. The first-start configuration already
sets the download and incomplete paths, binds peer traffic to `wg0-mullvad`,
keeps CSRF/clickjacking protection enabled, and disables WebUI UPnP.

Host-header validation is intentionally disabled because the loopback socket
proxy translates host port 18080 to container port 8080, which cannot satisfy
qBittorrent's strict port comparison. The WebUI remains protected by its native
authentication and CSRF/clickjacking checks and is reachable from outside the
container only through the host-loopback proxy and Tailscale ACLs. NixOS
reconciles the VPN binding and these security preferences on every start;
unrelated WebUI changes remain persistent.

## Application wiring

All application credentials and generated API keys belong in the application
state, which is encrypted in Borg. Do not paste them into ordinary Nix values.

### SABnzbd

Open `https://sabnzbd.liger-shilling.ts.net`. The paths, categories,
host-loopback proxy, tailnet hostname, and non-secret Eweka connection policy
are already declarative. Enter only the Eweka username and password in the
existing server, then select **Test Server** and save. Verify **Config → Servers** shows:

| Setting | Value |
| --- | --- |
| Host | `news.eweka.nl` |
| Port | `563` |
| SSL | Enabled |
| Certificate verification | Strict |
| Connections | `20` |

Nix reasserts the hostname, TLS policy, and connection count after every
restart while preserving credentials in SABnzbd's bind-mounted mutable state.
The provider connection uses the `sab` container's independent Mullvad tunnel
and strict NNTP/TLS. TLS protects credentials and article traffic from the VPN
exit to the provider, while the provider can still associate usage with the
paid account.

Confirm the declared folders and categories:

| Category | Complete folder |
| --- | --- |
| `sonarr-usenet` | `/srv/media/usenet/complete/tv` |
| `radarr-usenet` | `/srv/media/usenet/complete/movies` |
| `lidarr-usenet` | `/srv/media/usenet/complete/music` |

The incomplete folder is `/srv/media/usenet/incomplete`. Copy SABnzbd's API key
from **Config → General** into the download-client settings below; do not put it
in the repository. SABnzbd verifies `X-Forwarded-For` and treats only Tailscale's
CGNAT and IPv6 ranges as local, allowing named-service clients without opening
the loopback listener to a host interface.

### qBittorrent

In **Tools → Options → Downloads**:

- Confirm the default save path is `/srv/media/torrents/`.
- Confirm incomplete torrents use `/srv/media/torrents/incomplete/`.
- Set the default torrent management mode to **Automatic**.

Create these categories:

| Category | Save path |
| --- | --- |
| `sonarr` | `/srv/media/torrents/tv` |
| `radarr` | `/srv/media/torrents/movies` |
| `lidarr` | `/srv/media/torrents/music` |

Keep the WebUI on port 8080 inside the container, leave WebUI UPnP disabled,
keep the advanced **Network interface** setting on `wg0-mullvad`, and do not
open a peer port on Kim. A fixed peer port cannot become reachable through
Mullvad because the provider no longer supports forwarded ports.

### Sonarr, Radarr, and Lidarr

Open each manager's tailnet URL, complete its authentication setup, then add
qBittorrent as the download client using:

| Setting | Sonarr | Radarr | Lidarr |
| --- | --- | --- | --- |
| Host | `127.0.0.1` | `127.0.0.1` | `127.0.0.1` |
| Port | `18080` | `18080` | `18080` |
| Category | `sonarr` | `radarr` | `lidarr` |
| Root folder | `/srv/media/library/tv` | `/srv/media/library/movies` | `/srv/media/library/music` |

Use the permanent qBittorrent WebUI credentials. The paths are identical on
both sides of the container boundary, so remote-path mappings are neither
needed nor desirable.

Add SABnzbd as a second download client:

| Setting | Sonarr | Radarr | Lidarr |
| --- | --- | --- | --- |
| Host | `127.0.0.1` | `127.0.0.1` | `127.0.0.1` |
| Port | `18081` | `18081` | `18081` |
| Use SSL | No | No | No |
| API key | SABnzbd API key | SABnzbd API key | SABnzbd API key |
| Category | `sonarr-usenet` | `radarr-usenet` | `lidarr-usenet` |

These names intentionally differ from the qBittorrent categories because each
manager requires a unique category per configured download client.

The loopback download-client connection is intentionally HTTP; Tailscale HTTPS
protects browser access and SABnzbd separately uses strict NNTP/TLS to reach the
provider. Remote-path mappings are not needed.

Start with one conservative 1080p profile in Sonarr and Radarr:

- Include HDTV-1080p, WEB 1080p, and Bluray-1080p.
- Exclude remux and every 2160p/4K quality.
- Set a cutoff that stops upgrades once the chosen 1080p target is reached.
- Enable completed-download handling and hardlinks instead of copy/delete.
- Choose an explicit seed ratio or seed-time policy before enabling automatic
  torrent removal.

### Prowlarr

Open `https://prowlarr.liger-shilling.ts.net` and add NZBGeek under **Indexers**
using its HTTPS URL and API key. Test the indexer before enabling automatic
searches. Configure only source accounts you are authorized to use, then add
these applications with their API keys:

| Application | Internal URL |
| --- | --- |
| Sonarr | `http://127.0.0.1:8989` |
| Radarr | `http://127.0.0.1:7878` |
| Lidarr | `http://127.0.0.1:8686` |

Use full synchronization for every application. SABnzbd and qBittorrent still
need to remain configured directly in each manager; Prowlarr distributes
indexers but does not replace download-client connections.

### Bazarr

Open `https://bazarr.liger-shilling.ts.net`, configure authorized subtitle
providers, then connect Sonarr at `http://127.0.0.1:8989` and Radarr at
`http://127.0.0.1:7878` with their API keys. No qBittorrent or Prowlarr
connection is needed. Bazarr writes subtitle files beside the movie and episode
files, so keep its paths identical to the Sonarr and Radarr library paths.

### Jellyfin

Open `https://jellyfin.maximilian.pw`, create the administrator, and
add these libraries:

| Library type | Folder |
| --- | --- |
| Movies | `/srv/media/library/movies` |
| Shows | `/srv/media/library/tv` |
| Music | `/srv/media/library/music` |

LAN playback is available at `http://kim:8096`. Internet playback uses the
Cloudflare tunnel; there is no direct router port-forwarded Jellyfin endpoint.

### Tunarr

Open `https://tunarr.liger-shilling.ts.net`. Tunarr is paired with Nixpkgs
FFmpeg (currently 8.1.2, above its 7.1 minimum) and an embedded Meilisearch
binary. Then wire the two applications:

1. In Jellyfin, create an API key named `Tunarr` under **Dashboard → Advanced →
   API Keys**.
2. In Tunarr, add a Jellyfin media source at `http://127.0.0.1:8096` using that
   key. The key remains in backed-up Tunarr state, not in Nix.
3. Create a transcode configuration for 1920×1080 H.264/AAC. Select **VAAPI**,
   use driver `radeonsi`, and keep the device at `/dev/dri/renderD128`.
4. Create a channel, add programs from the synchronized Jellyfin library, and
   assign the VA-API transcode configuration.
5. In Jellyfin **Dashboard → Live TV**, remove the old ErsatzTV M3U tuner and
   guide. Add an **HDHomeRun** tuner manually at `http://127.0.0.1:8000`, then
   add an **XMLTV** provider at `http://127.0.0.1:8000/api/xmltv.xml`.
6. Refresh guide data and play the channel from Jellyfin's **Live TV** section.

Tunarr continuously advances each channel's timeline but starts an FFmpeg
session only while a client is watching. Prometheus probes
`/api/system/health`; because Tunarr always returns HTTP 200 there, the blackbox
probe also fails when the response contains `"type":"error"`.

### Seerr

Open `https://seerr.maximilian.pw`, sign in through Jellyfin, then add:

| Service | Internal URL |
| --- | --- |
| Jellyfin | `http://127.0.0.1:8096` |
| Sonarr | `http://127.0.0.1:8989` |
| Radarr | `http://127.0.0.1:7878` |

Select the existing 1080p profiles and root folders. Keep request approval
enabled until the complete download-import-playback path has been proven.

## Acceptance checks

Check the host services and container boundary:

```nu
systemctl status jellyfin tunarr sonarr radarr lidarr bazarr prowlarr seerr container@qbt container@sab qbittorrent-proxy.socket sabnzbd-proxy.socket
sudo nixos-container run qbt -- mullvad status
sudo nixos-container run qbt -- systemctl status qbittorrent --no-pager
sudo nixos-container run sab -- mullvad status
sudo nixos-container run sab -- systemctl status sabnzbd --no-pager
```

Confirm VA-API access as the actual service identity:

```nu
sudo -u jellyfin vainfo --display drm --device /dev/dri/renderD128
```

Before relying on hardware transcoding, confirm the output reports the codecs
declared in `homelab/media.nix`: H.264, HEVC/10-bit, VP9, and AV1 decoding plus
H.264, HEVC, and AV1 encoding. Remove any unsupported profile from the Nix
configuration and rebuild before continuing.

Then perform lawful movie, episode, and album tests:

1. Send one NZB through an application. Confirm NZBGeek supplied the result,
   SABnzbd used the expected category, and **Config → Servers** still reports
   SSL enabled with strict certificate verification.
2. Confirm each manager imports completed Usenet content into its matching
   library root. It may move the file because Usenet has no seeding requirement.
3. Test one torrent fallback. Confirm qBittorrent places it in the matching
   category and the manager hardlinks it into the library; compare device and
   inode numbers with `stat` and require a link count of at least two.
4. Confirm Jellyfin direct-plays one item.
5. Play a Tunarr channel from Jellyfin Live TV and confirm its guide data and
   current program match the configured lineup.
6. Force a lower playback bitrate, confirm the stream transcodes, and inspect
   Jellyfin's FFmpeg log for VA-API rather than software encoding.
7. Run `sudo nixos-container run qbt -- mullvad disconnect` and verify torrent
   traffic stops while SABnzbd, host Tailscale, and Jellyfin remain reachable.
   Confirm qBittorrent does not fall back to its container veth, then run
   `sudo nixos-container run qbt -- mullvad connect`.
8. Repeat with `sab`: use `mullvad disconnect` and verify Usenet traffic stops
   while qBittorrent and the host remain reachable. Confirm SABnzbd does not
   fall back to its container veth, then run `mullvad connect`. Do not stop the
   `mullvad-daemon` unit for this test.

## Backups

Borg preserves the control plane:

- Jellyfin users, libraries, metadata, and watch state
- Tunarr's Jellyfin connection, channels, lineups, transcode profiles, and guide
  state; its rebuildable sparse `data.ms` search index is excluded
- Sonarr, Radarr, Lidarr, Bazarr, and Prowlarr configuration/databases
- SABnzbd configuration, provider credentials, API keys, queue, and history
- Seerr configuration/database
- both downloader container roots, including qBittorrent's resume/configuration
  state and each container's independent Mullvad device login

The coordinator stops each downloader's host proxy socket before stopping its
container. This prevents monitoring or Servarr polling from socket-activating
the container again while Borg archives `/var/lib/nixos-containers/{qbt,sab}`
and `/var/lib/sabnzbd`. The media bind mounts live only in each container's
private mount namespace; downloaded files remain outside the archived control
state and are excluded separately.

Downloaded files below `/srv/media` are intentionally excluded. Hardlinks save
space but are not backups: deleting both directory entries or losing the `/srv`
filesystem loses the media. Irreplaceable personal media needs a separate
off-host copy.

## Jellyfin 12.0 upgrade

[Jellyfin 12.0 release notes](https://jellyfin.org/posts/jellyfin-release-12.0/)
describe a database rewrite on first start. Building the new configuration does
not perform this migration. Schedule a maintenance window before activating it
on Kim.

The local packages are `packages/jellyfin.nix`, `packages/jellyfin-web.nix`, and
`packages/jellyfin-ffmpeg.nix`. They pin server/web 12.0.0 and Jellyfin FFmpeg
8.1.2-4 because the pinned nixpkgs packages still ship 10.11.11. The server uses
.NET 10 and `packages/jellyfin/nuget-deps.json`; regenerate that manifest with
`jellyfin.fetch-deps` when changing its dependencies. Update server and web
together, and remove the coordinated overrides when nixpkgs catches up.

Build without activating:

```sh
nix build .#jellyfin .#jellyfin-web .#jellyfin-ffmpeg --no-link
```

1. Check the **running** server version in the dashboard. Direct upgrades are
   supported from 10.10.7 and any 10.11.x release. Older servers must first
   upgrade to 10.10.7. The previous flake package was 10.11.11, but that does not
   prove which generation Kim is running.
2. Resolve usernames that differ only by capitalization before the upgrade.
   Usernames become case insensitive and collisions make the migration fail.
   Remove third-party plugins, not just disable them. Only reinstall versions
   rebuilt for 12.0 and .NET 10. Bookshelf is deprecated; its replacements are
   built-in book support and the GoogleBooks, ComicVine, and OpenLibrary
   metadata providers.
3. Stop Jellyfin and take a full manual backup of `/var/lib/jellyfin`, including
   its `config/` directory, before activating the new generation. Preserve
   ownership and permissions. Keep the backup outside Git and the Nix store,
   verify it can be read, and retain an off-host copy. Record the old Git
   revision, system generation, and running Jellyfin version with it. The
   regular Borg backup is useful but does not replace this pre-upgrade backup.
4. Activate only after confirming the backup. Watch `journalctl -u jellyfin -f`
   and let migrations finish without stopping or restarting the server. The
   upstream `--mode MigrateSystem` option can migrate and exit, but is not an
   automatic pre-start hook here.
5. Run a **full library scan** after migration. Automatically grouped alternate
   versions are cleared during the upgrade and look missing until the scan
   rebuilds them. The first scan takes longer than usual and some corrected
   movies may appear newly added. Let it finish.
6. Hard-refresh the web client or clear its cache. Check subtitle settings in
   each library; the server-wide settings have been removed. Update old clients
   that use `/emby/`, `/mediabrowser/`, or deprecated authentication.
7. Run the [acceptance checks](#acceptance-checks), including direct play and
   VA-API transcoding. Verify Seerr login and requests, Tunarr source sync, and
   a Live TV channel with guide data. M3U tuners now remux rather than direct
   play. Confirm users, watch state, collections, playlists, and alternate
   versions survived before reinstalling compatible plugins.

**A NixOS generation rollback alone is not a database rollback.** If the upgrade
fails, keep Jellyfin stopped and restore the full pre-upgrade state with the
matching old package version. Follow the staging and ownership rules in
[the homelab recovery runbook](homelab-recovery.md); do not start 10.11 against
a database already migrated by 12.0.

## Recovery

1. Restore and mount `/srv` before starting any media service.
2. Rebuild the archived Nix revision so package versions match the backup
   manifest.
3. Restore Borg's `/var/lib` content, including both
   `/var/lib/nixos-containers/{qbt,sab}` and `/var/lib/sabnzbd`, plus the other
   declared control-state paths.
4. Start `container@qbt` and `container@sab`. Confirm Mullvad is connected in
   each namespace before confirming qBittorrent and SABnzbd are running or
   unmasking their host proxy sockets.
5. Start Prowlarr, Sonarr, Radarr, Lidarr, Bazarr, Jellyfin, Tunarr, and Seerr.
   Confirm the restored Usenet provider uses port 563, SSL, and strict
   certificate verification before resuming its queue.
6. Run the acceptance checks above. If downloaded media was not separately
   protected, reconcile missing files in the library managers rather than
   assuming their restored databases represent files that still exist.

If either Mullvad device credential cannot be restored or has been revoked,
repeat the interactive account login in that container. Never place the account
number in this file, the Nix store, or command history.

## Troubleshooting

If qBittorrent is unavailable, check Mullvad first:

```nu
sudo nixos-container run qbt -- mullvad status
sudo nixos-container run qbt -- journalctl -u qbittorrent -u mullvad-daemon -b --no-pager
```

Repeated qBittorrent pre-start failures mean the privacy gate is working: the
downloader will retry every 30 seconds but will not start until Mullvad reports
a connection. If the WebUI works internally but not through its tailnet name,
check `qbittorrent-proxy.socket`, `tailscale-serve.service`, and the tailnet ACL
grant for `svc:qbittorrent`.

If SABnzbd cannot download, check its independent Mullvad connection before
testing the provider in **Config → Servers**:

```nu
sudo nixos-container run sab -- mullvad status
sudo nixos-container run sab -- journalctl -u sabnzbd -u mullvad-daemon -b --no-pager
```

Repeated SABnzbd pre-start failures mean the privacy gate is working. Do not
work around certificate errors by disabling verification or switching to
plaintext port 119. Check the container's clock/DNS, the provider hostname,
credentials, and the provider's current SSL endpoint instead. If the WebUI
works inside the container but not through its tailnet name, check
`sabnzbd-proxy.socket`, `tailscale-serve.service`, and the ACL grant for
`svc:sabnzbd`.

The design and operational choices are based on the
[TRaSH native layout](https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Native/),
[Jellyfin AMD acceleration guide](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/amd/),
[Tunarr installation guidance](https://tunarr.com/getting-started/installation/),
[Tunarr's Jellyfin client guide](https://tunarr.com/configure/clients/jellyfin/),
[qBittorrent headless guidance](https://github.com/qbittorrent/qBittorrent/wiki/Running-qBittorrent-without-X-server-%28WebUI-only%29),
and [Mullvad CLI guidance](https://mullvad.net/help/how-use-mullvad-cli).
