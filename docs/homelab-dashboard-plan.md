# Homelab dashboard, calendar, and observability plan

## Outcome

Create a polished, balanced daily hub that combines:

- Frequently used personal, VEV, and RBI links.
- Clearly grouped self-hosted applications.
- Nextcloud Calendar as the calendar source of truth, with Apple Calendar as the
  iPhone interface.
- A private Grafana/Prometheus monitoring stack for Kim.
- Enough health information on Homepage to know when Grafana needs attention,
  without turning Homepage into a wall of duplicated status labels.

## Decisions already made

- Homepage links replace the current page (`target = "_self"`).
- Nextcloud Calendar will replace the existing calendar source of truth.
- Grafana/Prometheus is preferred over Beszel.
- Grafana remains private through Tailscale Serve.
- Tailscale identity headers provide seamless Grafana authentication.
- Prometheus starts with node, systemd, and SMART exporters only.
- No custom dashboard application, Loki, Alertmanager, media stack, Wallabag,
  Calibre, Forgejo, or unrelated homelab collection work in this project.

## Current worktree

There is an incomplete draft in the working tree:

- `homelab/homepage.nix` has an initial flat Frequent bookmark group.
- `homelab/nextcloud.nix` declaratively installs Calendar.
- `tests/homepage-calendar-regression.nix` and its flake check are drafted.
- `docs/nextcloud-calendar.md` documents iPhone CalDAV setup.
- `docs/homelab-dashboard-research.md` records primary-source research.
- `flake.lock` was modified before this work and must not be overwritten or
  folded into these changes accidentally.

The implementation should reshape the draft rather than layering another
configuration on top of it.

## Phase 1: deepen the homelab presentation seam

### Goal

Keep routing and presentation knowledge local while exposing a small interface
to Homepage.

### Work

1. Add Grafana to `lib/homelab.nix` as a private service endpoint.
2. Replace the flat `homepageServices` result with one exported
   `homepageServiceGroups` interface containing ordered `Applications` and
   `Operations` groups.
3. Keep card-construction helpers private to `lib/homelab.nix`; do not create a
   generic public schema when Homepage is the only presentation adapter.
4. Continue deriving Tailscale Serve routes from `privateServices`, so adding
   Grafana automatically enters the existing Serve regression surface.

### Application groups

**Applications**

- Home Assistant
- Nextcloud
- Paperless
- Miniflux
- Buzz

**Operations**

- Grafana
- Uptime Kuma
- Syncthing
- T3 Code

Every card receives a real icon, concise description, and direct local health
monitor. Status uses a dot rather than repeated `OK • Nms` text.

## Phase 2: redesign Homepage

### Goal

Make Homepage a useful start page rather than an inventory of installed tools.

### Global presentation

- Dark theme.
- Zinc or slate palette.
- Clean headers.
- Equal-height cards.
- Status-dot presentation.
- Current-tab navigation.
- Hide version/update noise.
- Use native Homepage layout and icons before adding custom CSS.

### Header widgets

- Date/time in the local browser locale.
- Open-Meteo weather without an API key.
- Search with a small provider dropdown.
- Keep host resources compact initially; replace them with Prometheus summaries
  later if the information is duplicated.

Start with browser geolocation for weather because Homepage is already served
through HTTPS. If permission prompts are annoying, replace it with coarse city
coordinates after confirming the desired location.

### Bookmark groups

All are compact launchers with icons and short labels. They do not receive site
monitors or descriptions.

**Everyday**

- GitHub — `https://github.com/`
- Pull Requests — `https://github.com/pulls`
- YouTube — `https://www.youtube.com/`
- X — `https://x.com/`
- Calendar — `https://nextcloud.maximilian.pw/apps/calendar/`
- Chess.com — `https://www.chess.com/`
- Reddit — `https://www.reddit.com/`
- Letterboxd — `https://letterboxd.com/`

**VEV**

- Outlook — `https://outlook.cloud.microsoft/mail/`
- Lucca Schedule — `https://vev.ilucca.net/work-locations/schedule`
- VEV GitHub — `https://github.com/VEV-platform-services`
- AWS Access Portal — `https://d-8067153cb2.awsapps.com/`
- Linear — `https://linear.app/`

**RBI**

- PostHog — `https://eu.posthog.com/project/216724/web`
- RBI Landing — `https://github.com/maximilianpw/rbi-landing`
- Cloudflare — `https://dash.cloudflare.com/a2ca791db3863dceb49557db0f0f3647/rivierabeauty.com`
- Riviera Beauty — `https://rivierabeauty.com/`

Use Dashboard Icons or Simple Icons for known brands and restrained Material
Design fallbacks for Lucca/Riviera Beauty. Verify every chosen icon slug instead
of relying on a broken remote icon.

### Initial layout

Keep one page initially:

1. Header widgets
2. Everyday
3. VEV
4. RBI
5. Applications
6. Operations

Review it on desktop and iPhone before introducing tabs. If it becomes too
long, move only Operations to a second tab; do not split daily links across
multiple tabs.

## Phase 3: Nextcloud Calendar

### First deployment

1. Keep Calendar in `services.nextcloud.extraApps` so installation is
   declarative and reproducible.
2. Keep the direct Calendar bookmark available immediately.
3. Preserve `appstoreEnable = true` because existing UI-managed apps must remain
   available alongside packaged apps.
4. Keep the iPhone CalDAV instructions in `docs/nextcloud-calendar.md`.

### User setup after deployment

1. Create the desired calendars in Nextcloud.
2. Generate a dedicated Nextcloud device password for Apple Calendar.
3. Connect the iPhone through CalDAV and verify two-way event sync.
4. Create a dedicated read-only iCal share for the Homepage agenda.

### Second deployment: Homepage agenda

1. Add a `homepage-calendar-url` sops secret containing the read-only iCal URL.
2. Render it into a root-readable Homepage environment file using
   `sops.templates`.
3. Attach the file through `services.homepage-dashboard.environmentFiles`.
4. Reference the secret through Homepage environment substitution; never embed
   the bearer URL in Nix or the world-readable Nix store.
5. Add a compact agenda widget with a small event limit and local timezone.

The agenda is deliberately a second deployment because the read-only feed does
not exist until Calendar is enabled and configured.

## Phase 4: Prometheus and exporters

Create `homelab/monitoring.nix` and import it from `homelab/default.nix`.

### Prometheus

- Bind to `127.0.0.1` only.
- Keep the default internal port unless a repository conflict is found.
- Scrape every 15–30 seconds.
- Retain 30 days with a hard 5 GiB storage ceiling.
- Enable configuration checking.
- Do not expose Prometheus through Cloudflare or Tailscale Serve.

### Node exporter

Collect machine-wide:

- CPU and load
- Memory and swap
- `/` and `/srv` filesystems
- Disk I/O
- Network traffic
- Uptime
- Hardware sensors where supported

Bind to loopback only.

### systemd exporter

Bind to loopback and include only operationally important units:

- Grafana and Prometheus
- Tailscale and Tailscale Serve
- PostgreSQL
- Home Assistant
- Nextcloud/nginx/PHP-FPM
- Paperless units
- Miniflux
- Syncthing
- Uptime Kuma
- Homepage
- Buzz
- Borg backup and check units/timers

Use an include expression rather than exporting every system unit. Enable
restart-count metrics when supported.

### SMART exporter

- Bind to loopback only.
- Monitor both NVMe devices explicitly after verifying their actual device
  paths on Kim.
- Use the native NixOS capability/device policy rather than running a container
  as unrestricted root.
- Keep existing `smartd`; the exporter adds history and visualization rather
  than replacing proactive SMART monitoring.

## Phase 5: Grafana

### Exposure and authentication

1. Bind Grafana to `127.0.0.1` on its homelab-assigned port.
2. Expose it as `grafana.<tailnet>` through the existing Tailscale Serve module.
3. Enable Grafana auth-proxy authentication using
   `Tailscale-User-Login` as the email identity.
4. Trust the auth header only from loopback.
5. Disable public signup and anonymous access.
6. Auto-create the authenticated tailnet user with enough access for Grafana
   Explore, while keeping the provisioned dashboard repository-owned.
7. Treat tailnet grants as the outer authorization layer.

This avoids both anonymous Grafana and a second daily password prompt. Grafana
must never listen on LAN/tailnet interfaces directly because that would allow
identity-header spoofing.

### Provisioning

- Provision Prometheus as the default datasource.
- Store dashboard files under `homelab/grafana/`.
- Provision dashboards read-only from Nix.
- Use a stable dashboard UID so Homepage can link directly to the overview.
- Do not import a huge community dashboard as the primary interface.

### `Kim Overview` dashboard v1

The first row should answer the important questions at a glance:

- CPU utilization
- Memory pressure
- Root filesystem usage
- `/srv` usage
- Failed important systemd units
- Overall SMART status

Supporting rows:

- CPU, load, and memory history
- Root and storage growth
- Disk I/O and latency
- Network receive/transmit
- CPU and NVMe temperatures
- Important unit state and restart count

Use a restrained dark visual style, consistent units, useful thresholds, and a
small number of panels. Avoid decorative gauges and duplicated series.

## Phase 6: Homepage monitoring summary

After Prometheus is live, add one compact Prometheus metric card to Operations:

- CPU utilization
- Memory utilization
- `/srv` utilization
- Failed important units

The card links to `Kim Overview`. Keep Uptime Kuma responsible for endpoint
availability; do not recreate all Kuma monitors in Prometheus or Homepage.

Do not configure Homepage's Grafana widget initially: it reports dashboard and
alert counts rather than the host health needed on the daily page, and it would
require a broad Grafana credential. Query loopback Prometheus directly instead.

## Phase 7: backup ownership

Prometheus history and provisioned Grafana state are reproducible operational
state, not primary user data.

- Exclude `/var/lib/prometheus2` from Borg to avoid backing up a live TSDB/WAL
  and consuming space with disposable metrics.
- Keep Grafana dashboards and datasource definitions in the repository.
- Exclude `/var/lib/grafana` if all desired Grafana configuration is
  declarative; otherwise explicitly stop Grafana during Borg before retaining
  its SQLite database. Prefer the declarative/excluded design.
- Do not put Prometheus data on `/srv` merely because space is available; cap it
  on the root SSD and revisit only if actual retention needs exceed the limit.

## Phase 8: backup freshness and alerts

Defer this until the basic graphs are useful.

1. Add a tiny node-exporter textfile metric recording the timestamp of the last
   successful Borg backup.
2. Show backup age in Grafana and optionally Homepage.
3. Add an alert only after choosing an iPhone notification destination.
4. Reuse Uptime Kuma/Apprise or add ntfy rather than inventing another delivery
   mechanism.

This small repository-specific metric is a justified custom module. A custom
visual dashboard application is not.

## Deferred product candidates

Only revisit these when they address an observed workflow:

- Karakeep if links, PDFs, and screenshots are currently being lost.
- Immich if replacing or supplementing iCloud Photos becomes a goal.
- Network DNS filtering if ad/tracker blocking is desired and Kim can become a
  critical DNS dependency.

Do not add services merely to make Homepage look populated.

## Tests

### Homepage/calendar regression

Assert:

- Bookmark group names, order, and exact URLs.
- Global link target remains `_self`.
- Applications and Operations remain separate.
- Calendar remains a declarative Nextcloud app.
- The Calendar bookmark points to the public Nextcloud endpoint.
- No calendar bearer secret appears directly in generated Nix configuration.

### Monitoring regression

Assert:

- Grafana, Prometheus, and exporters bind only to loopback.
- Retention is 30 days and capped at 5 GiB.
- Only expected systemd units are included.
- Grafana auth proxy uses the Tailscale identity header and loopback whitelist.
- Anonymous access is disabled.
- The Prometheus datasource and `Kim Overview` dashboard are provisioned.
- Prometheus/Grafana disposable state is excluded from Borg.
- Grafana is present in the Tailscale Serve-generated command set.

### Dashboard validation

- Parse the dashboard JSON during Nix evaluation.
- Verify required dashboard UID, datasource UID, panel titles, and queries.
- Keep queries compatible with the exact pinned exporter versions.

## Verification

Run the smallest relevant checks before rollout:

1. `alejandra --check .`
2. `make lint` and confirm Statix succeeds.
3. `nix flake check --no-build`
4. `git diff --check`
5. Review the diff and confirm the pre-existing `flake.lock` change was not
   modified by this work.

Do not run `make rebuild` until explicitly requested.

## Rollout and acceptance

### Rollout 1

Deploy Homepage restructuring, Nextcloud Calendar, Grafana, Prometheus, and
exporters together after checks pass.

Verify:

- Every bookmark opens the expected destination in the same tab.
- Homepage is clean on desktop and iPhone.
- Grafana opens through Tailscale without a Grafana login prompt.
- Direct LAN access to Grafana and exporter ports fails.
- All Prometheus targets are healthy.
- Both NVMe devices report expected metrics.
- `Kim Overview` contains real data and no broken panels.

### Rollout 2

After Nextcloud Calendar is configured, add the sops-managed iCal URL and agenda
widget.

Verify:

- Apple Calendar creates and edits Nextcloud events.
- Homepage displays only the intended read-only calendar.
- Revoking the share breaks only the agenda, not CalDAV access.

### Visual review

Use the dashboard for one week before adding more integrations. Remove cards or
metrics that are not consulted. The acceptance criterion is not the number of
services displayed; it is whether the page becomes a useful default starting
point.
