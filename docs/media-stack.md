# Media stack on Kim

Kim runs Jellyfin, ErsatzTV, Sonarr, Radarr, Lidarr, Bazarr, Prowlarr, Seerr,
SABnzbd, and qBittorrent as one private media-automation stack. This
configuration is intended for a personal library and sources the operator is authorized to use.
Source and indexer accounts are deliberately not declared in this repository.

## Architecture

Jellyfin, ErsatzTV, the Servarr managers, Prowlarr, Bazarr, Seerr, and SABnzbd
are native NixOS services. qBittorrent runs in a declarative systemd-nspawn
container with its own network namespace and Mullvad daemon:

```text
Tailnet HTTPS                  Kim                         qbt container
---------------        ---------------------       ------------------------
jellyfin.*  ---------> Jellyfin :8096              Mullvad lockdown + tunnel
ersatztv.*  ---------> ErsatzTV :8409                     |
sonarr.*    ---------> Sonarr   :8989                     |
radarr.*    ---------> Radarr   :7878               qBittorrent :8080
lidarr.*    ---------> Lidarr   :8686                     ^
bazarr.*    ---------> Bazarr   :6767                     |
prowlarr.*  ---------> Prowlarr :9696                     |
sabnzbd.*  ---------> SABnzbd  :18081 --NNTP/TLS--> provider
seerr.*     ---------> Seerr    :5055                     |
qbittorrent.* -------> 127.0.0.1:18080 socket proxy -----'

LAN enp194s0 --------> Jellyfin :8096 and discovery UDP :7359
```

The host's Tailscale routing is untouched. Only the container veth is NATed to
the physical interface. Mullvad's early-boot blocker and lockdown mode prevent
unprotected routing, while qBittorrent is additionally bound to Mullvad's
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

qBittorrent can see only `torrents/`; SABnzbd writes only under `usenet/`.
Sonarr, Radarr, and Lidarr can read and write the whole tree to import completed
downloads into `library/`. Bazarr can update subtitle files in
the movie and television libraries. Jellyfin can manage `library/` but cannot
see either active download tree. ErsatzTV has read-only access to `library/` and
cannot see either download tree. All services that touch `/srv` require the
mount and fail closed instead of writing into the root filesystem when it is
missing.

## First deployment

Apply the configuration when ready:

```nu
make rebuild
```

The initial qBittorrent starts will fail safely until the container is logged
into Mullvad. Open a root shell inside the container:

```nu
sudo nixos-container root-login qbt
```

That shell is Bash. Read the account number without placing it in shell
history, log in, and restart qBittorrent:

```bash
read -rs -p "Mullvad account number: " MULLVAD_ACCOUNT; echo
mullvad account login "$MULLVAD_ACCOUNT"
unset MULLVAD_ACCOUNT
mullvad status
systemctl restart qbittorrent
systemctl status qbittorrent --no-pager
exit
```

The pre-start gate reapplies LAN access, auto-connect, and lockdown mode and
will refuse to launch qBittorrent unless `mullvad status` begins with
`Connected`. Mullvad's device credential persists inside the backed-up
container state; the account number is not stored in Nix or the repository.

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

Open `https://sabnzbd.liger-shilling.ts.net`. The paths, categories, loopback
listener, tailnet hostname, and non-secret Eweka connection policy are already
declarative. Enter only the Eweka username and password in the existing server,
then select **Test Server** and save. Verify **Config → Servers** shows:

| Setting | Value |
| --- | --- |
| Host | `news.eweka.nl` |
| Port | `563` |
| SSL | Enabled |
| Certificate verification | Strict |
| Connections | `20` |

Nix reasserts the hostname, TLS policy, and connection count after every
restart while preserving credentials in SABnzbd's mutable state. The provider
connection runs directly from Kim over NNTP/TLS; it does not use the
qBittorrent Mullvad container. TLS protects credentials and article traffic in
transit, while the provider can still associate usage with the account.

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

Open `https://jellyfin.liger-shilling.ts.net`, create the administrator, and
add these libraries:

| Library type | Folder |
| --- | --- |
| Movies | `/srv/media/library/movies` |
| Shows | `/srv/media/library/tv` |
| Music | `/srv/media/library/music` |

LAN playback is available at `http://kim:8096` for clients that cannot run
Tailscale. There is no direct Internet or router port-forwarded Jellyfin
endpoint.

### ErsatzTV

Open `https://ersatztv.liger-shilling.ts.net`. Then wire the two applications:

1. In Jellyfin, create an API key named `ErsatzTV` under **Dashboard → Advanced
   → API Keys**.
2. In ErsatzTV, open **Media Sources → Jellyfin**, connect to
   `http://127.0.0.1:8096` with that key, and synchronize the Movies and Shows
   libraries. The key remains in backed-up ErsatzTV state, not in Nix.
3. Select streaming from disk. ErsatzTV sees the same library paths as Jellyfin,
   so no path replacements are needed. It has read-only access to those files.
4. Create a collection, channel, and playout in ErsatzTV. Start with the default
   FFmpeg profile and HLS Segmenter mode; configure a VA-API profile only after
   confirming a test stream works.
5. In Jellyfin, open **Dashboard → Live TV**. Add an **M3U Tuner** using
   `http://127.0.0.1:8409/iptv/channels.m3u`, then add an **XMLTV** guide provider
   using `http://127.0.0.1:8409/iptv/xmltv.xml`.

The resulting channels appear under Jellyfin's **Live TV** section. They run on
an always-on schedule, but ErsatzTV only transcodes while a client is watching.

### Seerr

Open `https://seerr.liger-shilling.ts.net`, sign in through Jellyfin, then add:

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
systemctl status jellyfin ersatztv sonarr radarr lidarr bazarr prowlarr sabnzbd seerr container@qbt qbittorrent-proxy.socket
sudo nixos-container run qbt -- mullvad status
sudo nixos-container run qbt -- systemctl status qbittorrent --no-pager
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
5. Play an ErsatzTV channel from Jellyfin Live TV and confirm its guide data and
   current program match the configured playout.
6. Force a lower playback bitrate, confirm the stream transcodes, and inspect
   Jellyfin's FFmpeg log for VA-API rather than software encoding.
7. Stop Mullvad in the container and verify torrent traffic stops while SABnzbd,
   host Tailscale, and Jellyfin remain reachable. Confirm qBittorrent does not
   fall back to the container veth, then reconnect before continuing.

## Backups

Borg preserves the control plane:

- Jellyfin users, libraries, metadata, and watch state
- ErsatzTV's Jellyfin connection, collections, channels, schedules, and guide
  state
- Sonarr, Radarr, Lidarr, Bazarr, and Prowlarr configuration/databases
- SABnzbd configuration, provider credentials, API keys, queue, and history
- Seerr configuration/database
- the qBittorrent container root, including resume data, configuration, and
  the Mullvad device login

The coordinator stops each mutable service while copying it. Stopping the qbt
container also unmounts its torrent bind mount before Borg traverses
`/var/lib/nixos-containers/qbt`.

Downloaded files below `/srv/media` are intentionally excluded. Hardlinks save
space but are not backups: deleting both directory entries or losing the `/srv`
filesystem loses the media. Irreplaceable personal media needs a separate
off-host copy.

## Recovery

1. Restore and mount `/srv` before starting any media service.
2. Rebuild the archived Nix revision so package versions match the backup
   manifest.
3. Restore Borg's `/var/lib` content, including
   `/var/lib/nixos-containers/qbt`, plus the other declared control-state paths.
4. Start `container@qbt`, confirm Mullvad is connected, and only then confirm
   qBittorrent is running.
5. Start SABnzbd, Prowlarr, Sonarr, Radarr, Lidarr, Bazarr, Jellyfin, ErsatzTV,
   and Seerr. Confirm the restored provider uses port 563, SSL, and
   strict certificate verification before resuming its queue.
6. Run the acceptance checks above. If downloaded media was not separately
   protected, reconcile missing files in the library managers rather than
   assuming their restored databases represent files that still exist.

If the Mullvad device credential cannot be restored or has been revoked, repeat
the interactive account login. Never place the account number in this file,
the Nix store, or command history.

## Troubleshooting

If qBittorrent is unavailable, check Mullvad first:

```nu
sudo nixos-container run qbt -- mullvad status
sudo nixos-container run qbt -- journalctl -u qbittorrent -u mullvad-daemon -b --no-pager
```

Repeated qBittorrent pre-start failures mean the privacy gate is working: the
daemon will retry every 30 seconds but will not start until Mullvad reports a
connection. If the WebUI works internally but not through its tailnet name,
check `qbittorrent-proxy.socket`, `tailscale-serve.service`, and the tailnet ACL
grant for `svc:qbittorrent`.

If SABnzbd cannot download, inspect its service log and test the provider in
**Config → Servers**:

```nu
journalctl -u sabnzbd -b --no-pager
```

Do not work around certificate errors by disabling verification or switching to
plaintext port 119. Check Kim's clock/DNS, the provider hostname, credentials,
and the provider's current SSL endpoint instead. If the WebUI works on loopback
but not through its tailnet name, check `tailscale-serve.service` and the ACL
grant for `svc:sabnzbd`.

The design and operational choices are based on the
[TRaSH native layout](https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Native/),
[Jellyfin AMD acceleration guide](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/amd/),
[qBittorrent headless guidance](https://github.com/qbittorrent/qBittorrent/wiki/Running-qBittorrent-without-X-server-%28WebUI-only%29),
and [Mullvad CLI guidance](https://mullvad.net/help/how-use-mullvad-cli).
