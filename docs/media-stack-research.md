# Media stack decision record

Status: accepted on 2026-08-02 after research performed on 2026-08-01.

This record preserves the design rationale. The current deployment and recovery
instructions live in [the media-stack runbook](media-stack.md); when the two
documents differ, the runbook and Nix configuration are authoritative.

## Decision

1. Run Jellyfin, Sonarr, Radarr, Prowlarr, and Seerr as native NixOS services.
   Run qBittorrent in a declarative systemd-nspawn container so Mullvad cannot
   replace Kim's host routes or interfere with Tailscale.
2. Keep downloads and the finished library on one ext4 filesystem under
   `/srv/media`. qBittorrent sees only `torrents/`, Sonarr and Radarr can
   hardlink into `library/`, and Jellyfin can manage the finished library while
   remaining unable to access active downloads.
3. Use a shared `media` group, setgid directories, and umask `0002` for all
   four writers, including Jellyfin.
4. Fail qBittorrent closed with Mullvad's early-boot blocker and lockdown mode,
   a connection gate before daemon startup, and an explicit qBittorrent bind to
   `wg0-mullvad`. Accept reduced peer connectivity because Mullvad does not
   provide forwarded ports.
5. Publish administrative UIs only through named Tailscale Services. Expose
   Jellyfin playback and discovery on Kim's physical LAN for clients that
   cannot join the tailnet; do not expose the stack directly to the Internet.
6. Start with conservative 1080p profiles and treat downloaded media as
   replaceable. Borg protects application control state but deliberately
   excludes `/srv/media`; personal or irreplaceable media needs a separate
   off-host copy.

## Rationale

The shared filesystem layout follows the TRaSH native-layout convention. It
allows instant hardlink imports without duplicating data while qBittorrent
continues seeding. Separate service identities and a shared writer group keep
the required collaboration narrow.

The qBittorrent container adds a network namespace without moving the rest of
the stack away from the well-supported NixOS modules. A host-loopback socket
proxy gives Sonarr, Radarr, and Tailscale Serve one endpoint while keeping the
container WebUI closed on Kim's external interfaces.

The proxy translates port 18080 to qBittorrent's port 8080, so qBittorrent's
strict host-header port validation cannot remain enabled. Native WebUI
authentication, CSRF and clickjacking protection, the loopback-only host
listener, and Tailscale ACLs are the compensating boundaries.

## Operational constraints

- Keep application credentials, API keys, source accounts, and the Mullvad
  account number out of ordinary Nix values and the repository.
- Verify `wg0-mullvad` exists and qBittorrent remains bound to it during the
  first deployment and every recovery drill.
- Run `vainfo` as the Jellyfin service identity and verify every declared
  decode and encode profile before relying on hardware transcoding.
- Configure explicit seed limits and bounded quality profiles before enabling
  unattended automation. Existing `/srv` filesystem alerts remain the storage
  guardrail.
- Preserve matching package versions and quiesced state for Jellyfin, Servarr,
  Seerr, and the qBittorrent container in every Borg recovery point.

## Deferred companions

Bazarr and Recyclarr may be useful after the core
download-import-playback-transcode path is proven. FlareSolverr, archive
unpackers, a second download protocol, and a public request portal remain out of
scope until a demonstrated workflow requires them.

## Primary references

- [TRaSH native layout](https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Native/)
  and [hardlink explanation](https://trash-guides.info/File-and-Folder-Structure/Hardlinks-and-Instant-Moves/)
- [Jellyfin AMD acceleration](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/amd/)
  and [networking guidance](https://jellyfin.org/docs/general/post-install/networking/)
- [qBittorrent VPN binding](https://github.com/qbittorrent/qBittorrent/wiki/How-to-bind-your-vpn-to-prevent-ip-leaks)
  and [headless guidance](https://github.com/qbittorrent/qBittorrent/wiki/Running-qBittorrent-without-X-server-%28WebUI-only%29)
- [Mullvad CLI guidance](https://mullvad.net/help/how-use-mullvad-cli)
