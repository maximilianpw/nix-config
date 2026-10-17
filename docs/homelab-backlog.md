# Homelab backlog

Active procedures live in [the recovery runbook](homelab-recovery.md) and the
service runbooks. This file contains only work that still needs an external
decision or a measured acceptance gate.

## Disaster recovery

| Work | Owner or decision | Completion gate |
| --- | --- | --- |
| Off-site encrypted backup destination | Choose a provider, retention model, credentials, and pinned host identity where applicable. | A separate machine can list and extract the off-site repository using only the recovery kit. |
| Independent SOPS and identity recovery | Create an offline Age identity outside Kim and 1Password, and keep the Borg passphrase and provider recovery instructions with it. | The offline identity decrypts a copied SOPS file and the kit opens the off-site backup. |
| Real restore drill records | Run quarterly drills from a dated archive and store each record under `docs/restore-drills/` and outside Kim. | The major application checks in the recovery runbook pass from staged data. |
| Optional storage migration or encryption | Decide whether LUKS2 or a different filesystem has a measured benefit. | Do not migrate until two verified copies exist, one is off-site, and a full restore drill has passed. |

## Monitoring and policy

| Work | Owner or decision | Completion gate |
| --- | --- | --- |
| External heartbeat and alert destinations | Choose providers and supply their URLs through SOPS. Explicitly deferred during the follow-up to the October 11 review. | A deliberately withheld heartbeat and a test alert both reach the operator. |
| Secondary-media SMART coverage | Run the read-only `homelab-media-smart-check` with device-read privileges; do not enable unverified USB passthrough. | Verified SAT telemetry from the pinned LaCie disk, followed by exporter configuration and post-activation coverage checks. |
| October 12 monitoring activation | Separately authorize a rebuild for disk-runway alerts, retained kernel-error telemetry and read-only preflight commands. | Loaded rules pass fixtures; the kernel collector refreshes its textfile; a disposable fault fixture fires and clears. |
| Cloudflare and Tailscale policy ownership | Choose provider-managed configuration or a documented source of truth with read-only drift audits. | CI validates policy, drift is reported, and intended plus unauthorized identities are tested. |
| Machine-level Tailscale Serve drift | Extend the audit beyond named services. | `homelab-check` fails on an undeclared machine-level handler. |
| Authorization and network review | Decide Grafana default roles, Nextcloud's private-network egress exception, Syncthing's LAN versus tailnet policy, and the remaining Docker exposure and group access. | Each choice has a regression check or an explicit accepted-risk note. |
| CLIProxyAPI backend readiness | The public `/healthz` route returns an unconditional 204 from nginx and never contacts the proxy. Keep that ingress signal public and add a separate authenticated, non-billable backend probe; the loopback quota endpoint already exercises the proxy's auth state and is a candidate. Any inference canary is separately enabled, infrequent, and budgeted. | Disposable fixtures show ingress staying healthy while the backend probe fails with the upstream down. No credentials appear in probe arguments, logs, or store paths. |

## Deferred operations

| Work | Owner or decision | Completion gate |
| --- | --- | --- |
| Homepage calendar agenda | Create a dedicated read-only Nextcloud iCal share and store its bearer URL in SOPS, never in Nix source or the store. | The agenda shows only the intended calendar and revoking the share affects only the agenda. |
| Container retention policy | Classify long-running development containers with explicit labels. | Reports are trusted before any automation is considered; unlabeled or production containers remain report-only. |
| Legacy Stocket database retirement | Confirm intermittent consumers and data-retention/export needs before separately authorizing removal of `stocket-dev-postgres-1`; preserve `stocket-dev_postgres-data-v18` initially. | The current native development stack works without the legacy container, and required data remains independently recoverable. |
| Root capacity after scheduled cleanup | The October 12 timer succeeded and freed 10.3 GiB; root remains about 81% utilized. Review source snapshots, Docker caches and migration artifacts before authorizing selective cleanup. | Root free space recovers and remains stable after the Stocket Git-aware launcher is propagated; rollback and data retention are preserved. |
| Shorter Uptime Kuma backup outage | Evaluate an online SQLite snapshot or a brief stop-and-copy artifact. | A staged restore retains monitors, history, and notification delivery before the current quiesce window changes. |
