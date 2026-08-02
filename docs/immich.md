# Immich on Kim

Immich runs natively through the NixOS module and is available only on the
tailnet at <https://immich.liger-shilling.ts.net>. Its uploaded originals,
thumbnails, transcoded videos, profiles, and built-in database dumps live under
`/srv/immich`; PostgreSQL and Redis use local Unix sockets.

## First sign-in

After rebuilding Kim:

1. Open <https://immich.liger-shilling.ts.net> from a device connected to the
   tailnet.
2. Create the initial administrator account. Immich permits this only until the
   first account exists.
3. In the iOS or Android app, set the server endpoint to the same URL and sign
   in. Select the albums to back up before enabling automatic backup.

The first thumbnail, metadata, face-detection, and smart-search jobs can use
substantial CPU. This rollout intentionally starts with CPU processing; enable
the Radeon GPU only after the baseline service and its recovery path are known
good.

## Backups

The normal Kim Borg job stops `immich-server.service`, creates the shared
PostgreSQL logical dump, and archives `/srv/immich` before restarting the
service. This keeps database references and media files in the same recovery
point. Immich's own scheduled database dumps under `/srv/immich/backups` are a
second restore aid, not a replacement for Borg: they do not contain photos or
videos.

Do not edit files below `/srv/immich` manually. Use the Immich web or mobile UI
so filesystem contents and database metadata remain consistent. The full
service recovery procedure is in [the homelab runbook](homelab-recovery.md#immich).
