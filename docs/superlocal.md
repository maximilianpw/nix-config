# Superlocal on Kim

Superlocal is a private Tailscale service at
`https://superlocal.liger-shilling.ts.net`: a unified email client with an Inbox
SDK host for Gmail, Outlook, IMAP and Inbound mailboxes. The tailnet is its only
access control. The service runs in Superlocal's `loopback` mode, which accepts
this one HTTPS Tailscale Serve origin and refuses public origins.

## Source and updates

The `superlocal` flake input (`git+ssh://git@github.com/maximilianpw/superlocal`,
private) is pinned in `flake.lock`. Kim builds it from source; no container
image or registry is involved.
- `lib/mksystem.nix` imports the input's `nixosModules.default` on homelab hosts.
- `homelab/superlocal.nix` configures it.
- The package uses the input's own nixpkgs, because it needs Bun 1.4 or newer.

Deploy a new version by moving the pin, building, and switching:

```sh
nix flake update superlocal
make build      # optional: build without switching
make rebuild
```

The evaluating user fetches the input with their GitHub SSH key. `nh` builds as
that user and elevates only for activation. Rolling back the NixOS generation
rolls back the code. It does not undo SQLite migrations; see Recovery.

## Ports and ingress

- Web client: `127.0.0.1:19011`. This is the inventory endpoint that Tailscale
  Serve proxies to.
- Local API: `127.0.0.1:19012`. Only the web client reaches it.

The inventory adds `svc:superlocal` to the Tailscale Serve reconciler. If the
tailnet requires service creation or host approval, approve only
`svc:superlocal` for Kim before expecting the URL to resolve.

## First start and real mailboxes

The first start creates `/var/lib/superlocal/superlocal.local.json` in `mock`
mode, with two fictional mailboxes. To connect real mail, edit it as the service
user with the service stopped. Set `mode` to `real` and enable providers as
described in Superlocal's README ("Connect real providers"):

```sh
sudo systemctl stop superlocal.service
sudo -u superlocal $EDITOR /var/lib/superlocal/superlocal.local.json
sudo systemctl start superlocal.service
```

Keep the generated `instanceId`. The data directory is keyed to it.

Gmail needs a Google OAuth web client. Register
`https://superlocal.liger-shilling.ts.net/v1/oauth/google/callback` as a
redirect URI. To supply the client ID and secret:
1. Create `secrets/superlocal.yaml` with `sops`, holding a dotenv-style value
   that sets `SUPERLOCAL_GOOGLE_CLIENT_ID` and `SUPERLOCAL_GOOGLE_CLIENT_SECRET`.
2. Declare it as a sops secret owned by `superlocal`, with mode `0400` and
   `restartUnits = ["superlocal.service"]`.
3. Set `services.superlocal.environmentFile` to its path.

This wiring is not present yet, because no OAuth client exists for this origin.

## State and secrets

Everything mutable lives in `/var/lib/superlocal`. Superlocal requires owner
`superlocal`, directory mode 0700 and file mode 0600, and refuses to start
otherwise.
- `superlocal.local.json`: instance ID, mode and provider settings.
- `data/<mode>/`:
  - `host.sqlite` and the mail databases
  - `runtime-secrets.json`, which holds the credential encryption and session
    keys
  - `performance.jsonl`

The databases contain real mail and encrypted provider credentials, and the keys
decrypt them, so this directory must only ever be copied as a whole.

## Recovery

Follow `docs/homelab-recovery.md` and restore into isolated staging first. The
inventory quiesces `superlocal.service` while archiving `/var/lib/superlocal`,
and the backup manifest records the deployed version, including the flake input
revision.

1. Stop Superlocal before replacing state.
2. Restore the entire directory: the configuration, the databases with their
   SQLite sidecar files, and `runtime-secrets.json`. Keys that are missing or
   don't match fail closed, and Superlocal never regenerates them over existing
   data.
3. Preserve owner `superlocal:superlocal`, directory modes 0700 and file modes
   0600.
4. Check SQLite integrity in an isolated instance, with separate ports and no
   Tailscale Serve.
5. Confirm the mailbox list loads and a cached conversation opens without
   reauthorizing providers.
6. Only then expose the service.

For a code rollback, keep the previous NixOS generation. A generation rollback
doesn't undo database migrations. If the older version can't read the newer
schema, restore the matching pre-upgrade archive together with its package
version, and keep the service stopped until then.
