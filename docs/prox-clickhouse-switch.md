# Safe prox / ClickHouse switch on Kim

This change prepares a switch; it does **not** enable or deploy it. The default
keeps Kim's existing `pkgs.cliproxyapi` unit and requires no new secrets or
ClickHouse service. Fleet is pinned to merged PR #3, commit
`56a16ba614f97cc05907f8692d214716558d3e28`; that also updates the packaged prox UI
served by the existing Nginx alias. The UI reports unavailable history on the
old backend rather than generating mock statistics.

## Approval and source pins

Fleet currently packages CLIProxyAPI source
`c050425e8dcc70654bef4745ccf62eed699f39da` from
[backend PR #1](https://github.com/maximilianpw/CLIProxyAPI/pull/1). That PR is
still draft/unmerged at preparation time. Do not enable the switch merely
because this consumer PR merges. First merge/review the backend separately and
confirm the approved source matches the package pin. If the backend changes,
update Fleet's source/vendor hashes, merge that packaging update, then update
this consumer's Fleet pin/lock and regression's expected backend revision.
A squash merge can have a different commit ID: compare its source with the
pinned source rather than assuming they are identical.

The `reviewedBackendRevision` assertion is a deliberate operator approval gate,
not an online GitHub merge-status check. It rejects missing or stale approval;
Nix never silently follows a branch.

## Prepare secrets and retain identity

Using the existing SOPS editor workflow (`sops secrets/secrets.yaml`), add two
different generated hex passwords under these keys, encrypted to the existing
admin and Kim recipients from `.sops.yaml`:

* `cliproxyapi-clickhouse-password`: runtime SELECT/INSERT user password.
* `cliproxyapi-clickhouse-admin-password`: schema administrator password.

Do not commit plaintext, put values in Nix, paste them into a thread, or put
them in shell arguments/history. No secret values are supplied by this PR.
The enabled module renders two root-owned `0400` files under `/run/secrets`:
the backend receives only `CLICKHOUSE_QUOTA_PASSWORD`; ClickHouse and schema
initialization also receive `CLICKHOUSE_QUOTA_ADMIN_PASSWORD`. Both reference
the same runtime-password SOPS placeholder. SOPS file changes restart the
affected services; coordinate rotations and check schema initialization.

Before an approved activation, confirm the existing auth directory is present
and take an operator-controlled encrypted backup outside this Git checkout.
Preserved values are:

* user `maxpw`, working directory `/home/maxpw`;
* existing `/home/maxpw/.cli-proxy-api` filenames and credential data;
* SOPS template `cliproxyapi.conf`, management key, API keys, model routing and
  upstream configuration (only panel auto-updates are disabled when enabled);
* Nginx `/management.html`, `/v0/management/`, `/v8/management/`, `/v1/` and
  `/quota/v1/` routes and authentication;
* quota sidecar on loopback port 8318, reading the same auth directory.

Do not copy, rename, recreate or recursively chown auth files. The new backend
checks that YAML `oauth.auth-dir` matches that existing directory. Its existing
Codex persistence may reserialize JSON and tighten file permissions to `0600`;
data/identity/path preservation does not promise identical bytes or inodes.

## Enable, build, then separately approve activation

After the prerequisites above, add this in `machines/kim.nix`:

```nix
homelab.cliproxyapi.quotaStatistics = {
  enable = true;
  reviewedBackendRevision = "c050425e8dcc70654bef4745ccf62eed699f39da";
};
```

Use the newly reviewed revision instead if Fleet's backend pin changed. From
the consumer checkout, these checks/builds do not activate anything:

```sh
nix flake check --no-build
nix build .#checks.x86_64-linux.cliproxy-statistics-regression --no-link
nix build .#checks.x86_64-linux.homelab-ingress-regression --no-link
nix build .#nixosConfigurations.kim.config.system.build.toplevel --no-link
```

The production checkout needs access to its private flake inputs. CI uses the
repository's Superlocal stub; a stubbed check is not a production build. Missing
SOPS entries must be provisioned before building the enabled host. Review the
generation diff and backups. Only after separate deployment approval, **on
Kim** in the approved `~/nix-config` checkout, run:

```sh
make rebuild
```

That command activates the host, starts ClickHouse and runs the packaged
idempotent schema initialization before the backend. No such command was run
while preparing this PR. ClickHouse binds only `127.0.0.1:8123/9000`; no new
public route or firewall port is opened. Data is in `/var/lib/clickhouse`,
database `cliproxy_quota`, table `quota_samples`, with 90-day TTL. Arrange a
separate ClickHouse-aware backup if history must survive host loss; the
existing auth backup is not a database backup. Initial schema creation does not
migrate an incompatible existing table: review any existing schema first.

## Acceptance after the approved rebuild

1. Check `systemctl status clickhouse cliproxyapi-quota-schema cliproxyapi
   cliproxyapi-quota` and inspect failures locally without publishing secrets.
2. Confirm the same credential IDs/accounts appear in the existing prox UI;
   confirm provider access and quota sidecar still work. Do not assume a healthy
   Nginx `/healthz` proves backend readiness; it deliberately returns a bare 204.
3. Using the existing management bearer key through the authenticated UI, check
   `/v8/management/observability/quota/history` and `/pools`. An empty configured
   database returns 200 with empty history/pools. 404 means the old backend;
   503 means missing/disabled configuration; 502 means storage failure; 422
   means too much data; 400 means an invalid query. No ClickHouse password is
   sent to the browser. See the backend's `docs/quota-statistics.md` for filters.
4. Successful v8 **plugin** quota fetches ingest real observations. Native
   requests/API-call quota fetches and the existing quota sidecar do **not**.
   Native accounts therefore need an approved collector/external canonical
   insertion path before they gain history. This PR installs no collector and
   backfills no invented data. Two or more useful observations are needed for
   rates; missing burn/drain/projections remain unavailable rather than zero.
5. Exercise UI time ranges/provider filters against those recorded samples.
   Preserve auth filenames: history keys use provider plus auth index.

For rollback, set `homelab.cliproxyapi.quotaStatistics.enable = false`, build,
review and separately approve another `make rebuild`. This returns to the
original backend unit and removes the new runtime-secret requirement; it does
not delete auth files or `/var/lib/clickhouse`. Do not use rollback as a database
cleanup command. Keep the encrypted backup until compatibility is confirmed.
