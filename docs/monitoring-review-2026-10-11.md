# Kim monitoring investigation — 2026-10-11

Follow-up to [the October 7 review](monitoring-review-2026-10-07.md).
Investigation used Kim's loopback Prometheus/Alertmanager APIs, filtered system
journals, filesystem and Nix metadata, Docker inspection, read-only PostgreSQL
catalog queries, and Cloudflare GraphQL analytics through Executor. Times below
are Europe/Berlin (CEST) unless explicitly marked UTC.

No configuration was activated, services restarted, databases changed, or user
files/store paths pruned. One ostensibly read-only `nix-store --query --roots`
call automatically removed stale GC-root links and temporary-root bookkeeping;
this was an incidental Nix side effect, not a garbage collection. No further
root enumeration or cleanup was requested. A local report and a sanitized
scratch log-summary script were written.

## Executive findings

1. **Root capacity is the first operational priority.** Root was 81.8% full,
   with approximately 155–156 GiB available. The measured weekly decline in
   available space was 76.5 GiB. Oversized Stocket worktree snapshots are a
   confirmed contributor: 48 snapshots larger than 1 GiB account for 113.6 GiB
   of logical NAR data, including ignored dependencies and local runtime data.
   This is not a measurement of unique physical/reclaimable bytes.
2. **The tunnel's 404 spike is a Plex download-client retry loop.** Cloudflare
   analytics attributes 3,781 responses to two endpoints for the same download
   queue item, using the same Apple-platform Plex user agent. The origin itself
   returned 404. No tunnel 404s were recorded in the final one-hour window.
3. **Actual's longer public incident was a DNS rollout gap.** Its local backend
   stayed healthy while public blackbox probes reported `no such host` on
   October 10. The October 11 brief failure coincided with backup quiescing.
4. **Tdarr's poor weekly availability is dominated by one stopped period, not
   an ongoing crash loop.** It was stopped for approximately 18½ hours during
   the October 5 secondary-disk incident. Recent short interruptions match
   backup windows.
5. **Stocket's legacy Docker database remains an orphan candidate.** Its
   owning Compose file no longer exists, current development uses native
   PostgreSQL, and no client sessions were present at inspection. Preserve its
   volume and confirm retention/consumers before retirement.
6. **Notification and secondary-disk health gaps remain.** Current alerts go
   to `local-sink`; the external heartbeat unit is absent. SMART telemetry
   covers only NVMe. No relevant kernel fault signatures were found since
   October 7, but LaCie SMART/integrity remains unverified.

## 1. Root filesystem growth

### Measurements

Prometheus queries:

```promql
100 * (1 - node_filesystem_avail_bytes{mountpoint="/"}
  / node_filesystem_size_bytes{mountpoint="/"})
(node_filesystem_avail_bytes{mountpoint="/"} offset 24h
  - node_filesystem_avail_bytes{mountpoint="/"}) / 1024^3
(node_filesystem_avail_bytes{mountpoint="/"} offset 7d
  - node_filesystem_avail_bytes{mountpoint="/"}) / 1024^3
```

At the initial check: 81.8% available-space utilization, 154.9 GiB available,
10.1 GiB net decline in 24 hours, and 76.5 GiB net decline in seven days.
A seven-day linear fit projected crossing the 90% threshold in about 3.8 days.
This is conditional on continuing growth, not a deadline: usage is bursty and a
scheduled cleanup is imminent. Available space was about 155.9 GiB at recheck.

### Confirmed oversized source snapshots

`nix path-info --all --json` reported approximately 413.4 GiB of total logical
NAR size. Of 54 `*-source` paths larger than 1 GiB (123.6 GiB total), 48 were
confirmed as Stocket Git worktree copies by their `.git` pointer metadata
(113.6 GiB total). They span ten worktree identities, including
`feat-catalog-drag-to-category`, `fix-smart-import-lean-reads`, and
`smart-import-06-wizard-cutover`.

The largest inspected snapshot was approximately 3.33 GiB. A recursive
`nix store ls --json --recursive` metadata listing showed:

- approximately 3.077 GiB under `node_modules`;
- approximately 0.111 GiB under `apps`;
- approximately 0.093 GiB under `.local`, including 2,122 PostgreSQL runtime
  file entries.

The copied `.gitignore` excludes dependency directories and `.local`, but the
snapshot nevertheless includes them, plus its worktree `.git` pointer. The
pointer resolves to a worktree managed under
`/home/maxpw/.local/share/t3code/worktrees/stocket/`.

**Established:** Nix ingested unfiltered Stocket working trees rather than a
tracked-files-only source set. **Not established:** the exact historical
command/launcher responsible, or the unique disk bytes attributable to these
copies. Auto store optimisation/hardlink sharing means NAR totals cannot be
added to `du` totals or interpreted as guaranteed cleanup savings. Store-root
ctime observations also are not a complete history of creation/deletion.

This is also an ownership/safety problem: local database runtime files should
not enter globally readable source snapshots. Only filenames/metadata were
inspected; no database content or credential values were read from the store.
Whether any non-synthetic/sensitive data was included remains unverified.

### Other capacity contributors

User-owned allocated sizes observed with bounded `du`:

| Tree | Approximate size | Interpretation |
| --- | --- | --- |
| `~/.local/share/Steam` | 157 GiB | Mostly installed game content; no evidence it caused this week's spike |
| `~/.local/share/t3code` | 12 GiB | About 8.6 GiB worktrees and 2.7 GiB userdata; application state, not disposable as a whole |
| `~/.local/state/t3code-pre-flake-20261008-101831` | 13 GiB | A migration snapshot; its `state.tar` is 12.45 GiB and was modified October 8 |
| `~/.local/share/Trash` | 14 GiB | Possible operator-reviewed recovery space |
| `~/.local/share/nixbench-local-models` | 21 GiB | Model data; retain unless intentionally retired |
| `~/.cache` | 23–26 GiB | Mixed tool/browser caches; live measurements vary |
| `~/.npm` | 13 GiB | Dependency cache |
| `~/.local/share/pnpm` | 11 GiB | Dependency store |
| system journal | 3.9–4.0 GiB | Bounded journal footprint, not the largest contributor |

`docker system df` reported 43.74 GB of images (30.65 GB reclaimable), 29.83 GB
of build cache (10.74 GB reclaimable), and 5.05 GB of volumes (4.84 GB marked
reclaimable). These figures may overlap and are not an instruction to prune.
An unused volume can still contain required data.

### Existing cleanup and next steps

`nh-clean` succeeded October 5, deleting 24,988 paths and reporting 14.5 GiB
freed. Its next scheduled run is **October 12 at 00:00 CEST**. Configuration
retains at least five generations and generations newer than 30 days; store
optimisation, `keep-outputs`, and `keep-derivations` are enabled.

Recommended order:

1. Recheck root available space and the cleanup result after the existing timer.
2. Identify/fix the launcher producing unfiltered Stocket worktree snapshots.
   Use a tracked/allowlisted source boundary that excludes dependencies,
   runtime databases, local environment files, and Git metadata. Filtering
   derivation `src` alone does not prevent an initial unfiltered flake copy.
3. Validate the source boundary using disposable fixtures before adoption.
4. If capacity still needs intervention, separately authorize selective cleanup
   with rollback/data-retention review. Preserve the T3 migration snapshot
   until migration acceptance and an independent recovery point are confirmed.

Protected/root-owned directory sizes were not comprehensively measurable with
this session's access. No claim that the breakdown accounts for every root byte.

## 2. Plex 404 spike and tunnel errors

The 24-hour tunnel counter showed approximately 3,795 HTTP 404 responses,
versus eight in the preceding day. Cloudflare's adaptive analytics for
October 10 20:00 UTC–October 11 20:00 UTC attributed:

| Host / path | Count |
| --- | ---: |
| `plex.maximilian.pw:443/downloadQueue/2/item/7/media` | 1,942 |
| `plex.maximilian.pw:443/downloadQueue/2/item/7/decision` | 1,839 |

The grouped requests used `Plex/2058 CFNetwork/3896.100.1.2.1 Darwin/27.0.0`.
Both edge and origin status were 404. They clustered in the 14:00–17:00 UTC
hour buckets (16:00–19:00 CEST). Cloudflare adaptive counts can be sampled;
the close agreement with the tunnel's counter is strong attribution evidence,
not proof that the two datasets count requests identically.

**Established:** an Apple-platform Plex client repeatedly requested the same
missing download-queue item; the tunnel did not manufacture the 404s.
**Likely:** a stale/missing download item plus client retries. The underlying
queue invalidation cause, client identity and exact platform were not proven.
No download queue was changed or replayed, and no client was disconnected.

At final check, `increase(cloudflared_tunnel_response_by_code{status_code="404"}[1h])`
was zero. If the problem recurs, inspect the affected Plex client's Downloads
state and the matching queue item before choosing client-side cancellation or
recreation. Do not change global tunnel routing to fix this symptom.

Tunnel request errors fell from approximately 173 to 87 per 24 hours while
requests rose from 10,295 to 15,666. Four HA connections remained up. Filtered
cloudflared logs from the corresponding period were dominated by incoming
request cancellation/remote stream cancellation, with a few origin connection
refusals around backups. Cancellation logs do not by themselves prove an ISP
or Cloudflare outage; duplicate log lines must not be equated with the metric's
request-error count.

Nginx access logs were permission-denied. Cloudflare analytics supplied the
404 attribution without relaxing permissions or printing credential-bearing
request URLs/query strings.

## 3. Actual Budget incidents

Sampled public probe failure window on October 10: approximately
**16:50–17:25 CEST**. The critical ingress alert fired approximately
17:00–17:25. Public probe HTTP status was zero and durations only milliseconds;
the loopback `/health` probe remained successful throughout.

Blackbox journal filtering found 14 error entries containing:

```text
lookup actual.maximilian.pw: no such host
```

This coincides with Actual's public exposure rollout: commit `0c092c3` was
recorded at 16:55 CEST, and monitoring/tunnel restarted around 16:50. Public
DNS/probe availability and activation were not aligned. The endpoint recovered;
this was not evidence of Actual's local server failing for 35 minutes.

On October 11, Actual stopped at 03:04:46 and restarted at 03:07:38 during the
03:00–03:09 backup. The five-minute public probe could remain failed until
its next scrape, accounting for the brief sampled failure near 03:10.

For future endpoint rollout, establish DNS resolution and public reachability
before treating the new endpoint as an established monitored service. Keep
backup-specific handling narrow rather than suppressing real ingress faults.

## 4. Tdarr availability and backup maintenance

The 88.8% weekly successful-probe fraction was dominated by one incident:
Tdarr stopped **October 5 at 01:30 CEST** and restarted at approximately
**20:00 CEST**, an 18½-hour stopped period. The journal shows a successful
stop, not a repeating crash loop. The October 5 kernel incident at the same
start time includes USB disconnect, I/O errors and journal abort signatures,
consistent with the documented media-disk incident. The initiating actor and
reason for leaving Tdarr stopped were not established.

Recent one-to-four-minute Tdarr probe failures align with its nightly backup
stops. On October 11 it stopped at 03:05:05 and started at 03:07:48. The backup
completed successfully at 03:09. This is expected quiescing behavior, not a
current repeated-restart problem.

Public probes are scraped every five minutes and local probes every minute.
Range-query steps reuse the most recent sample; failed-sample percentages and
window boundaries are not exact user-visible outage measurements. They also
do not account for every monitoring-data gap.

## 5. Legacy Stocket PostgreSQL container

`stocket-dev-postgres-1` is healthy, approximately 21 days old, and lacks a keep
label. Docker metadata identifies its old owner as
`/home/maxpw/local/stocket/ops/development/compose.yml`, which no longer exists.
It binds PostgreSQL to loopback port 5432 and uses the named volume
`stocket-dev_postgres-data-v18`.

The current Stocket README and dev launcher use native PostgreSQL 18 under
`.local/postgres`, not this Compose stack. A read-only `pg_stat_activity`
inspection found no other client backends at that instant. Database inventory
showed the development/test databases still present (each roughly 8–15 MB).
No application tables were read.

This supports the October 7 orphan finding, but absence of current sessions
is not proof that no intermittent consumer exists. Keep the named volume;
confirm consumers and data retention/export requirements before authorizing
retirement. Do not add a keep label solely to silence the alert.

## 6. Monitoring and LaCie reliability

- Alertmanager's active alert receivers are `local-sink`; these Prometheus
  alerts are not sent through an external webhook.
- `homelab-host-heartbeat.service` is not installed. An off-host heartbeat is
  needed to detect total Kim/monitoring failure independently.
- Choosing providers and supplying URLs through SOPS is already tracked in
  `docs/homelab-backlog.md`; no destination/provider was invented or configured.
- SMART exporter configuration names only the two NVMe devices. Both passed
  SMART at 31–32°C. The secondary drive is the ST5000LM000 LaCie disk; its
  device was not readable by this session, so SMART was not obtained.
- A filtered `_TRANSPORT=kernel` journal search since October 7 inspected 746
  entries and found no matching USB-disconnect/reset, I/O-error, filesystem
  error or journal-abort signatures. This is reassuring within retained logs,
  not an integrity check or proof that the earlier transport problem is fixed.
- `/srv/media-secondary` is mounted, with filesystem read-only/device-error
  gauges zero. These gauges cannot detect every transient USB fault.
- Media is excluded from Borg. Confirm an independent copy before any repair,
  offline filesystem assessment or physical cable/power/bridge work.
- Three running containers report no Docker health check (`kometa`, `tdarr`,
  `stocket-smart-import-run-pg`). This is absence of a health signal, not proof
  of failure. Tdarr has a separate endpoint probe.

Recommended monitoring additions: an external alert receiver plus off-host
heartbeat; verified read-only SMART passthrough for the LaCie; retained kernel
transport-error telemetry; and disk-growth/source-size visibility. These are
recommendations, not implemented changes.

## Current healthy baseline and verification limits

Initial live checks showed all 49 scrape targets up, all 42 endpoint probes
successful, no failed monitored units, no restart-counter increase in 24 hours,
and no OOM kills in seven days. CPU averaged 1.5% over 24 hours (4.2% p95),
memory use was approximately 20%, and pressure signals were low. CPU's lower
weekly average is directionally encouraging, but does not establish causality
for the recent performance changes.

CLIProxyAPI authenticated readiness was 100% successful in the preceding day;
Executor's container is healthy, confirming the earlier healthcheck remediation
is now active. Latest backup/check/cryptographic-verification ages were within
configured freshness limits. Those ages do not substitute for a restore drill.

Final Prometheus recheck still showed only the root-filesystem warning and
stale-container warning. No live remediation was attempted. The intended next
step is source-ingestion diagnosis/fix and post-timer capacity verification,
not broad cleanup, altered CPU weights, service restarts, or a tunnel protocol
change.

## Local remediation — 2026-10-12

External alert/heartbeat setup was explicitly deferred by the operator. The
remaining work is local source/configuration and fixture verification, without
activation or live cleanup.

### Stocket source-ingestion cause and fix

The responsible launcher was found in Stocket's
`.agents/configure-shell-profile`: its generated login profile evaluated
`nix print-dev-env "path:$stocket_repository_root"`. A disposable real-Nix Git
worktree reproduced the bug: the explicit `path:` reference copied ignored
synthetic runtime/dependency files; Git-aware evaluation of `.` excluded them.

The launcher now resolves `.` inside a repository-root subshell instead. The
existing relocated-checkout profile test was first changed to require that
reference and failed against the old launcher, then passed after the fix.
A real-Nix regression in `tools/verify/nix-source-test.sh` exercises the actual
managed-profile reference in a Git worktree whose path contains spaces and
asserts that local databases, dependencies and Git metadata are absent from
its store source. `qualification:check` includes that regression.

These changes are in `/home/maxpw/local/stocket`, not this configuration repo.
Existing installed login profiles and older worktrees were not rewritten.
Propagate the updated launcher and regenerate managed profiles through the
normal Stocket workflow; existing store snapshots remain until reviewed cleanup
or the normal timer can collect unrooted paths.

### Homelab configuration additions

- `HomelabFilesystemFillingSoon` forecasts crossing 90% utilization within seven
  days using a 24-hour trend, gated on less than 30% available space and a
  one-hour hold. Healthy, growing and recovering Promtool fixtures cover it.
- `homelab-storage-kernel-metrics` collects retained kernel storage-error counts
  once per minute into an atomic textfile. It emits fixed-category 15-minute
  gauges, not raw logs or credentials, and preserves the last complete sample
  on read/parse failure. A fault alert and collector-freshness alert cover both
  storage faults and a broken monitoring path. This does not infer disk health
  from ordinary USB resets or disconnects.
- `homelab-public-ingress-check` checks DNS/TLS/HTTP reachability for declared
  public health URLs or an explicit HTTPS health URL. Run it before declaring
  a new endpoint, for example `homelab-public-ingress-check
  https://new.maximilian.pw/health`, and again after activation. It rejects
  credential/query-bearing URLs, HTTPS downgrades and non-2xx final responses.
  DNS records still need an explicitly authorized provider operation; no DNS
  change was made for the already recovered Actual endpoint.
- `homelab-media-smart-check` provides a pinned-device, read-only SAT telemetry
  check. Healthy, failed, unsupported and missing-status fixtures are covered.
  Device-read privileges and real passthrough verification are still required
  before changing the SMART exporter's device list.

No changes to backup quiescing, Plex download queues, Docker volumes, rollback
retention, disk mounts or transport settings were made. Tdarr's historical stop
and Actual's DNS rollout are not reasons to weaken live outage alerts. The Plex
retry loop had already ceased; recurrence needs client-side investigation, not
a speculative tunnel/server patch.

Activation, existing-profile propagation, durable post-cleanup capacity
stability, verified LaCie SMART, and legacy database retirement are
explicit remaining acceptance gates tracked in `docs/homelab-backlog.md`.

### Verification and post-timer observation

Passed:

- Stocket `qualification:check` under pinned Bun 1.3.14: 56 tests, plus the
  real-Nix Git-worktree source-boundary regression.
- Stocket focused Prettier and ShellCheck checks; whitespace checks in both repos.
- Scoped Alejandra check, `make lint`, and `make check-scripts`.
- `checks.x86_64-linux.monitoring-regression` build, including Promtool runway/
  filesystem/kernel-alert fixtures and the three new CLI/collector fixture suites.
- `nix flake check --no-build` on the native Linux system. Initial evaluations
  encountered invalid cached store paths; after standalone re-evaluation of the
  unchanged affected checks, the complete check passed without source changes
  to those checks or clearing the evaluation cache.
- Both public/SMART helper packages built without activation.
- Public preflight against Actual, Leerr and Plex returned HTTP 200; the kernel
  collector read real retained logs into a disposable metrics directory and
  reported zero recent error counts. Task-created scratch scripts were removed.

The already scheduled October 12 midnight `nh-clean` completed successfully,
reporting 15,115 store paths deleted and 10.3 GiB freed. At the October 12
22:05–22:08 recheck, root had about 163 GiB available and Prometheus reported
approximately 81.0% available-space utilization. The root warning and legacy
container warning therefore remain; no scrape target or endpoint probe was
down. The timer provided some relief but is not acceptance of a durable fix.
No manual cleanup was triggered, and no new monitoring configuration or login
profile was activated during this work.
