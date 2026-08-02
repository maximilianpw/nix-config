# Media stack on Kim

Kim runs Jellyfin, Sonarr, Radarr, Prowlarr, Seerr, and qBittorrent as one
private media-automation stack. This configuration is intended for a personal
library and sources the operator is authorized to use. Source and indexer
accounts are deliberately not declared in this repository.

## Architecture

Jellyfin, Sonarr, Radarr, Prowlarr, and Seerr are native NixOS services.
qBittorrent runs in a declarative systemd-nspawn container with its own network
namespace and Mullvad daemon:

```text
Tailnet HTTPS                  Kim                         qbt container
---------------        ---------------------       ------------------------
jellyfin.*  ---------> Jellyfin :8096              Mullvad lockdown + tunnel
sonarr.*    ---------> Sonarr   :8989                     |
radarr.*    ---------> Radarr   :7878               qBittorrent :8080
prowlarr.*  ---------> Prowlarr :9696                     ^
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
│   └── tv/
└── library/
    ├── movies/
    └── tv/
```

qBittorrent can see only `torrents/`. Sonarr and Radarr can read and write the
whole tree so they can hardlink completed downloads into `library/`. Jellyfin
can see only a read-only `library/`. All services that touch `/srv` require the
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

Keep the WebUI on port 8080 inside the container, leave WebUI UPnP disabled,
keep the advanced **Network interface** setting on `wg0-mullvad`, and do not
open a peer port on Kim. A fixed peer port cannot become reachable through
Mullvad because the provider no longer supports forwarded ports.

### Sonarr and Radarr

Open `https://sonarr.liger-shilling.ts.net` and
`https://radarr.liger-shilling.ts.net`, complete their authentication setup,
then add qBittorrent as the download client using:

| Setting | Sonarr | Radarr |
| --- | --- | --- |
| Host | `127.0.0.1` | `127.0.0.1` |
| Port | `18080` | `18080` |
| Category | `sonarr` | `radarr` |
| Root folder | `/srv/media/library/tv` | `/srv/media/library/movies` |

Use the permanent qBittorrent WebUI credentials. The paths are identical on
both sides of the container boundary, so remote-path mappings are neither
needed nor desirable.

Start with one conservative 1080p profile in each app:

- Include HDTV-1080p, WEB 1080p, and Bluray-1080p.
- Exclude remux and every 2160p/4K quality.
- Set a cutoff that stops upgrades once the chosen 1080p target is reached.
- Enable completed-download handling and hardlinks instead of copy/delete.
- Choose an explicit seed ratio or seed-time policy before enabling automatic
  torrent removal.

### Prowlarr

Open `https://prowlarr.liger-shilling.ts.net`, configure only source accounts
you are authorized to use, then add these applications with their API keys:

| Application | Internal URL |
| --- | --- |
| Sonarr | `http://127.0.0.1:8989` |
| Radarr | `http://127.0.0.1:7878` |

Use full synchronization. qBittorrent still needs to remain configured
directly in Sonarr and Radarr; Prowlarr does not replace those download-client
connections.

### Jellyfin

Open `https://jellyfin.liger-shilling.ts.net`, create the administrator, and
add exactly two libraries:

| Library type | Folder |
| --- | --- |
| Movies | `/srv/media/library/movies` |
| Shows | `/srv/media/library/tv` |

LAN playback is available at `http://kim:8096` for clients that cannot run
Tailscale. There is no direct Internet or router port-forwarded Jellyfin
endpoint.

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
systemctl status jellyfin sonarr radarr prowlarr seerr container@qbt qbittorrent-proxy.socket
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

Then perform one lawful movie and episode test:

1. Confirm qBittorrent places each item in the matching category directory.
2. Confirm Sonarr/Radarr imports it into the matching library root.
3. Compare source and library files with `stat`; the device and inode numbers
   should match and the link count should be at least two.
4. Confirm Jellyfin direct-plays one item.
5. Force a lower playback bitrate, confirm the stream transcodes, and inspect
   Jellyfin's FFmpeg log for VA-API rather than software encoding.
6. Stop Mullvad in the container and verify torrent traffic stops while host
   Tailscale and Jellyfin remain reachable. Confirm qBittorrent does not fall
   back to the container veth, then reconnect before continuing.

## Backups

Borg preserves the control plane:

- Jellyfin users, libraries, metadata, and watch state
- Sonarr, Radarr, and Prowlarr configuration/databases
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
5. Start Prowlarr, Sonarr, Radarr, Jellyfin, and Seerr.
6. Run the acceptance checks above. If downloaded media was not separately
   protected, reconcile missing files in Sonarr/Radarr rather than assuming
   their restored databases represent files that still exist.

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

The design and operational choices are based on the
[TRaSH native layout](https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Native/),
[Jellyfin AMD acceleration guide](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/amd/),
[qBittorrent headless guidance](https://github.com/qbittorrent/qBittorrent/wiki/Running-qBittorrent-without-X-server-%28WebUI-only%29),
and [Mullvad CLI guidance](https://mullvad.net/help/how-use-mullvad-cli).
