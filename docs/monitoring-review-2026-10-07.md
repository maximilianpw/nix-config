# Kim monitoring review — 2026-10-07

Read-only review of September 28–October 4, 2026, with current-state checks on
October 7. Times are Europe/Berlin (CEST). Historical alerts and endpoint probes
were sampled at one-minute query steps; resource gauges at five-minute steps.
Public endpoints are scraped every five minutes: failed samples are evidence of
probe failures, not exact user-visible outage durations. No service activation,
restart, cleanup, repair, or live-data changes were performed for this review.

## Follow-up priorities

1. **Executor health mismatch:** Docker's unhealthy-container alert fired from
   October 1 at 11:31 for most of the rest of the week, and remains active.
   Container identity is `executor`. Its health check runs Bun against
   `http://127.0.0.1:4788/api/health`; the five most recent checks failed while
   declared backend probes pass. Determine actual partial failure versus an
   invalid check before changing the check or restarting the service.
2. **LaCie media reliability:** USB resets and read I/O errors continued after
   the UAS workaround. September 29's disconnect also logged lost writes and
   a journal I/O error. Assess transport/disk reliability and the monitoring
   gap; mounted status is not proof of integrity. See below.
3. **Public ingress intermittency:** all seven public endpoints had failed
   probes concentrated around September 30 23:15–October 1 06:10 and October 2
   01:05–03:15. Most failures had HTTP status 0 and approximately 9.5-second
   durations (consistent with the probe deadline); some had HTTP 502.
   Local backends were largely healthy outside nightly maintenance. Investigate
   the shared ingress/network path; root cause is not established.
4. **Stale development database:** `stocket-dev-postgres-1`, Compose project
   `stocket-dev`, triggered the stale-container warning throughout the week and
   still does. It is healthy, but older than three days without a keep label.
   Establish intended lifecycle and owning configuration before marking it
   persistent or retiring it. Do not delete database data to silence an alert.

Separate Herdr investigation tabs were started for these four topics. They are
read-only investigators; implementation and verification are coordinated by the
parent agent. Findings above describe the initial baseline.

## Remediation and investigation results

- **Executor:** confirmed inherited-healthcheck port mismatch. The original
  command returns connection-refused/exit 1 on port 4788; the same request on
  configured port 19005 returns HTTP 200 and exit 0. `homelab/executor.nix`
  now overrides the health command using the inventory port, preserving image
  timings. An evaluation regression failed before the fix and passes after it.
  After the first rebuild, runtime verification found another requirement:
  Docker's `--health-cmd` produces `CMD-SHELL`, but the image has no `/bin/sh`.
  The application still returns HTTP 200; Docker cannot launch the check.
  The follow-up configuration mounts only a static BusyBox binary at `/bin/sh`
  read-only, requiring no host libraries. The regression now guards that mount.
  `python3 scripts/tests/executor-healthcheck-runtime-test.py` tests the exact
  configured check in disposable containers with no external networking or
  production state: missing-shell failure reproduced, HTTP 200 became healthy,
  and HTTP 503 became unhealthy. **Follow-up not activated:** another explicitly
  authorized rebuild is needed for the shell mount.
- **Homelab MCP:** the historical restart loop failed during systemd credential
  deserialization, before application startup. The old Plex credential path
  contained spaces; the current module already uses a root-only whitespace-free
  alias and has regression coverage. The journal shows 44 deserialization
  failures before recovery at October 1 11:17:55; the sampled restart metric
  undercounts this short loop. No additional MCP patch is needed.
- **Stocket:** the investigator found the old Docker Compose owner removed and
  current project documentation describing Docker PostgreSQL as retired. The
  native development stop command does not manage this legacy container or its
  named volume. Do not label an orphan persistent merely to suppress the alert.
  Confirm consumers and data-retention/export requirements before separately
  authorizing retirement; preserve the volume initially.
- **Public ingress:** filtered blackbox/cloudflared logs support a shared
  outbound Cloudflare-path connectivity problem, not seven independent origin
  failures. Router/ISP versus Cloudflare edge remains unresolved; forcing HTTP/2,
  changing DNS, or extending timeouts is not evidence-backed. The configuration
  now pins cloudflared's metrics listener to `127.0.0.1:20241` and adds a
  Prometheus scrape job for tunnel connection/error history. **Activated and
  verified after rebuild:** `up{job="cloudflared"}` is 1 and the tunnel has four
  HA connections. This cannot recover historical metrics that were never scraped.
  Cloudflared request URLs can contain credentials; future log inspection must
  extract/redact narrow fields rather than copying raw request lines.
- **Filesystem monitoring:** new critical read-only and device-error alerts
  cover `/`, `/srv`, and `/srv/media-secondary` with a one-minute hold.
  Promtool fixtures exercise healthy, read-only, and device-error secondary-mount
  cases. **Activated and verified after rebuild:** both rules are loaded, healthy
  and inactive. Secondary-mount read-only/device-error gauges are both 0.
  These complement missing-mount/capacity checks but do not detect every USB
  reset or short I/O failure and are not integrity tests.
- **LaCie:** investigation confirmed `usb-storage` at 480 Mb/s with the UAS
  quirk active. Errors also recurred October 5: read failure at 00:23; disconnect
  while mounted at 01:30 with journal abort/lost writes; remount at 01:32;
  additional read failures at 02:43, 09:55 and 16:19. September 29 also remounted
  shortly before disconnect, so its earlier unmount did not make the final
  disconnect safe. The journal cannot distinguish deliberate unplugging from
  electrical dropout. Read-error results indicate transport failure without
  proving damaged sectors. SMART access was denied; disk health remains unknown.
  Obtain read-only SMART telemetry and assess independent media copies before
  any offline filesystem assessment or cable/power/bridge investigation.

### Verification of local changes

Passed: scoped Alejandra checks, `make lint`, `nix flake check --no-build`,
`git diff --check`, and builds of `executor-config-regression`,
`homelab-ingress-regression`, and `monitoring-regression` on `x86_64-linux`.
The monitoring regression now runs Promtool alert fixtures. The user rebuilt;
post-activation verification at October 7 16:15 confirmed tunnel telemetry and
filesystem rules, with no failed systemd units. It also caught Executor's
missing-shell failure. The follow-up Executor runtime fixture, configuration
regression, formatting/lint and flake evaluation pass, but its new shell mount
awaits another rebuild. Existing unrelated Leerr changes were left untouched.

## Fired incidents that have cleared

| Incident | Observed firing window (CEST) | Follow-up |
| --- | --- | --- |
| `/srv` filesystem warning | Active at week start through September 29 20:38 | Available-space utilization peaked near 91%; critical alert entered pending but did not fire. About 480 GiB available at review. Confirm expected source of the spike. |
| Jellyfin public ingress | October 1 04:16–04:25; October 2 01:16–01:20 | Shared ingress investigation. These are alert windows, not outage start/end times. |
| Seerr public ingress | October 2 02:11–02:15 | Shared ingress investigation. |
| Homelab MCP repeated restarts | October 1 11:25–11:47 | Approximately 38 restarts across the week; journal confirms repeated exit-code failures. Determine cause; no current restart alert. |

Many backend probes and some systemd units briefly entered pending around
03:00, coinciding with the scheduled nightly backup. No local-backend-down
alert reached firing. Confirm maintenance behavior rather than assuming that
all failed probes are faults or suppressing them indiscriminately.

## Secondary media drive

- **Identity:** LaCie enclosure, ST5000LM000-2AN170 SMR disk, serial `WCJ23AWJ`.
- **Mount:** `/srv/media-secondary`, ext4, label `media-secondary`, UUID
  `4139bef6-d76c-4c41-99f6-3fd6090bdcd1`.
- **Stable partition:** `/dev/disk/by-id/ata-ST5000LM000-2AN170_WCJ23AWJ-part2`.
  Kernel names changed `sdb2` → `sdc2` on September 29; now `sdb2` again.
- **Capacity:** nominal 5 TB, approximately 717 GiB used and 3.6 TiB available
  at review. Prometheus available-space utilization peaked at about 20.3%
  last week. No capacity warning fired.
- **Availability:** one brief pending missing-mount alert during September 29's
  reconnect; no missing-mount alert fired.
- **Reliability evidence (last week):** September 28 UAS abort/reset; September 29 17:55
  lost sync-page writes and JBD2 journal I/O errors during disconnect. At 17:56
  the reconnect selected `usb-storage` instead of UAS. Later USB resets/read
  I/O errors occurred October 1 at 04:04, 10:44, 19:28 and 19:32; October 2 at
  22:32; October 4 at 23:12. Cause and integrity impact are not established.
- **Monitoring limitation:** filesystem and absent-mount alerts include this
  drive, but the configured SMART exporter covers only the two NVMe drives.
- **Recovery limitation:** media on this drive is excluded from Borg backups.
  Independent library copies are needed if the media must be recoverable.

Read-only/device-error alert additions are described above. SMART coverage and
persistent kernel-event monitoring remain follow-up work; enabling unverified
USB SMART passthrough would not establish health.

See [storage guidance](homelab-storage.md#lacie-media-disk) and
[media layout](media-stack.md) before planning drive operations.

## Healthy signals and limits

- Prometheus, Alertmanager, node, systemd, PostgreSQL, and SMART exporter `up`
  series were present and successful at all one-minute query points.
- Boot timestamp was unchanged across the week; no recorded OOM kills.
- Sampled CPU busy peaked around 43%; memory usage around 34%.
- Both monitored NVMe SMART status gauges stayed healthy. This does not cover
  the LaCie or establish full storage integrity.
- Backup success age stayed below 24 hours; no backup-staleness alert fired.
  This is freshness evidence, not a restore test.
- At review, no failed systemd units or failed declared endpoint probes;
  stale-container and unhealthy-container alerts remained firing.
