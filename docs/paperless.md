# Paperless Operations

## Nextcloud integration

Nix installs Nextcloud's `integration_paperless` app. It adds an **Upload to
Paperless** action to the Nextcloud Files menu, which is safer than making
Paperless consume Nextcloud's internal data directory.

After applying the NixOS configuration:

1. In Paperless, create a non-admin user for Nextcloud if one does not already
   exist, then create an API token from that user's profile.
2. In Nextcloud, open **Personal settings → Paperless-ngx**, set the server URL
   to `https://paperless.tail7161c3.ts.net`, and enter the API token.
3. Select a small test document in Nextcloud Files, choose **Upload to
   Paperless**, and confirm it becomes searchable in Paperless.

Treat the token as a secret. Paperless exports do not include API tokens, so
create a new token and reconnect Nextcloud after a restore.

Do not point `/srv/paperless/consume` at any path below
`/srv/nextcloud/data`. Paperless removes successfully consumed input files, and
direct filesystem changes bypass Nextcloud's file cache. If unattended folder
ingestion is needed later, create a dedicated external-storage folder named
`Paperless Inbox` with explicit shared permissions; never use the whole
`Documents` folder. The Files action is the default workflow because it keeps
Nextcloud authoritative and makes each transfer intentional.

## Backup and restore drill

The Borg archive contains both `/srv/paperless/export`, produced by Paperless's
supported document exporter, and a PostgreSQL dump. Prefer the export for a
portable Paperless recovery. The database dump is a lower-level fallback and
also covers the other PostgreSQL-backed services.

Run this drill quarterly:

1. Record the configuration revision and Paperless version associated with the
   archive. Restore into the same Paperless version first; exporter/importer
   compatibility across versions is not guaranteed.
2. Stage the archive into a new empty directory. Never restore directly over
   live service paths:

   ```sh
   sudo borg-job-main list
   mkdir -p /var/tmp/paperless-restore-drill
   sudo borg-restore-main <archive> /var/tmp/paperless-restore-drill \
     srv/paperless/export home/maxpw/nix-config
   ```

3. Provision an empty disposable Paperless instance from the archived config
   revision. Do not import into the live database or an instance whose database
   dump has already been restored.
4. On that isolated instance, import the staged export with its installed
   `paperless-manage` wrapper:

   ```sh
   sudo paperless-manage document_importer \
     /var/tmp/paperless-restore-drill/srv/paperless/export
   sudo paperless-manage document_sanity_checker
   ```

5. Compare document, correspondent, tag, and document-type counts; test several
   searches; open original and archived files; and verify a non-PDF Office file
   processed through Tika.
6. Destroy the disposable instance and the staged plaintext restore once the
   result is recorded. After a real recovery, generate a new API token and
   reconnect the Nextcloud integration.

Never combine both recovery routes: either restore the Paperless PostgreSQL
database and matching media/data, or import the supported export into an empty
instance.

## Remaining external hardening

Three improvements deliberately remain outside this declarative change:

- Add storage encryption during a planned reinstall or disk migration; adding
  it in place is a destructive partitioning operation.
- Configure an encrypted off-site Borg destination after choosing its provider
  and supplying credentials from SOPS.
- Configure an external dead-man endpoint after choosing the notification
  service. A local-only alert cannot report full host or network loss.

Header-based single sign-on is intentionally not enabled. It requires a
separately reviewed identity-aware proxy and strict trusted-proxy boundaries;
the current Paperless endpoint remains tailnet-only with native authentication.
