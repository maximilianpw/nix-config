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
| External heartbeat and alert destinations | Choose providers and supply their URLs through SOPS. | A deliberately withheld heartbeat and a test alert both reach the operator. |
| Cloudflare and Tailscale policy ownership | Choose provider-managed configuration or a documented source of truth with read-only drift audits. | CI validates policy, drift is reported, and intended plus unauthorized identities are tested. |
| Machine-level Tailscale Serve drift | Extend the audit beyond named services. | `homelab-check` fails on an undeclared machine-level handler. |
| Authorization and network review | Decide Grafana default roles, Nextcloud's private-network egress exception, Syncthing's LAN versus tailnet policy, and the remaining Docker exposure and group access. | Each choice has a regression check or an explicit accepted-risk note. |
| CLIProxyAPI backend readiness | The public `/healthz` route returns an unconditional 204 from nginx and never contacts the proxy. Keep that ingress signal public and add a separate authenticated, non-billable backend probe; the loopback quota endpoint already exercises the proxy's auth state and is a candidate. Any inference canary is separately enabled, infrequent, and budgeted. | Disposable fixtures show ingress staying healthy while the backend probe fails with the upstream down. No credentials appear in probe arguments, logs, or store paths. |
| Quota service compatibility preflight | `cliproxyapi-quota.service` runs from the mutable `~/pi-config` checkout. Bounded restarts (`StartLimitBurst`/`StartLimitIntervalSec`) and inventory membership now make a missing or immediately failing entry point reach a monitored `failed` state after startup; that is crash-loop containment, not compatibility validation. A server that stays running while serving incompatible responses is still undetected. Decide whether a separate read-only preflight that checks the checkout and endpoint contract before activation is wanted, and define what compatibility means. | Either the preflight is implemented and a disposable fixture shows an incompatible checkout blocked before activation, or the decision not to add one is recorded and the runtime contract alone is accepted. |
| Kim build and service contention | No `max-jobs`, `cores`, or resource directives exist for the Nix daemon or the T3 service. Measure peak build memory and CPU alongside interactive agent sessions, then prefer `CPUWeight` and `IOWeight` on `nix-daemon.service` over hard limits so idle-machine builds keep full speed. Docker workloads need separate consideration. | Agent sessions and homelab services stay usable during representative concurrent builds, with the chosen weights and their rationale recorded. |

## Deferred operations

| Work | Owner or decision | Completion gate |
| --- | --- | --- |
| Homepage calendar agenda | Create a dedicated read-only Nextcloud iCal share and store its bearer URL in SOPS, never in Nix source or the store. | The agenda shows only the intended calendar and revoking the share affects only the agenda. |
| Container retention policy | Classify long-running development containers with explicit labels. | Reports are trusted before any automation is considered; unlabeled or production containers remain report-only. |
| Shorter Uptime Kuma backup outage | Evaluate an online SQLite snapshot or a brief stop-and-copy artifact. | A staged restore retains monitors, history, and notification delivery before the current quiesce window changes. |
