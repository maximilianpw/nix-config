# Homelab dashboard and observability research

## Decision summary

Build a **balanced daily hub** around the existing Homepage instance:

1. Date/time, compact weather, and search at the top.
2. A short agenda sourced from Nextcloud Calendar.
3. Icon-first links for frequently visited external sites.
4. Primary self-hosted applications grouped separately from operational tools.
5. A small health summary that links to a dedicated monitoring UI.

Do not reproduce the common homelab pattern of showing every installed service
as an equally prominent card. It creates an inventory, not a useful start page.

For monitoring, evaluate **Beszel before committing to Grafana**. Beszel is a
better product fit for a single host when the goal is attractive, useful host,
Docker, systemd, temperature, and SMART history with little configuration.
Grafana remains the better fit when flexible PromQL, custom metrics, fully
versioned dashboards, or monitoring additional hosts is the actual goal.

Do not build a custom dashboard application yet. Homepage already has the
necessary layout, presentation, calendar, bookmark, and Prometheus integration
points. A small custom metric exporter for backup freshness may eventually be
justified; replacing Homepage is not.

## Current repository fit

The existing design already has good boundaries:

- Homepage is loopback-only and exposed privately through Tailscale Serve.
- Public Nextcloud is exposed through Cloudflare Tunnel.
- Service addresses and Homepage cards are generated from `lib/homelab.nix`.
- Uptime Kuma handles availability monitoring.
- `/srv` is the stateful bulk-storage boundary.
- Borg backs up application data and PostgreSQL logical dumps.
- Kim already runs `smartd`, Docker, and systemd-managed native services.

The dashboard should preserve these boundaries. In particular, it should not
introduce NGINX Proxy Manager: the existing declarative Cloudflare and Tailscale
routing is safer and easier to reproduce.

## Homepage capabilities

The pinned Homepage package is version 1.12.3. Its native features are enough
to improve the presentation without a fragile custom frontend:

- Layout groups can use rows, explicit column counts, icons, ordering, tabs,
  hidden headers, and initially collapsed sections.
- Bookmark groups support icons-only presentation.
- It supports dark/light themes, restrained color palettes, card blur, optional
  backgrounds, PWA installation, and custom CSS.
- Quick Launch searches configured services and bookmarks by typing anywhere.
- Site-monitor status can be reduced from repeated latency labels to a simple
  status dot.
- Dashboard Icons, Simple Icons, Material Design Icons, and selfh.st icons are
  supported directly.

Recommended visual settings:

- Dark `zinc` or `slate` palette.
- `headerStyle = "clean"`.
- `statusStyle = "dot"` to remove repeated `OK • Nms` noise.
- Equal-height cards and consistent three-column service rows.
- Real icons for every service and external bookmark.
- No background image initially; typography, spacing, and hierarchy matter
  more than decoration.
- Avoid custom CSS until the native layout has been reviewed in a browser and
  on iPhone.

Sources:

- [Homepage settings and layouts](https://gethomepage.dev/configs/settings/)
- [Homepage services, icons, and status monitoring](https://gethomepage.dev/configs/services/)
- [Homepage bookmarks](https://gethomepage.dev/configs/bookmarks/)
- [Homepage custom CSS and JavaScript](https://gethomepage.dev/configs/custom-css-js/)

## Proposed information architecture

Keep one page initially. Add tabs only if the operations section overwhelms the
main page after real use.

### Top widgets

- Date and time.
- Open-Meteo weather, which requires no API registration. Homepage can request
  browser geolocation in its existing secure HTTPS context, avoiding a location
  committed to the repository.
- Search with DuckDuckGo, Brave, and Google in a provider dropdown.

Sources:

- [Homepage date/time widget](https://gethomepage.dev/widgets/info/datetime/)
- [Homepage Open-Meteo widget](https://gethomepage.dev/widgets/info/openmeteo/)
- [Homepage search widget](https://gethomepage.dev/widgets/info/search/)

### Agenda

Homepage's calendar widget supports monthly and agenda views plus iCal feeds.
Use the compact agenda view with a small event limit. Nextcloud should remain
the calendar source of truth, while Apple Calendar connects through CalDAV for
the polished iPhone experience.

An iCal subscription URL is a bearer secret. Do not place it directly in Nix,
because generated Homepage YAML is stored world-readable in `/nix/store`.
Pass it through a sops-managed Homepage environment file and reference it with
Homepage's environment-variable substitution.

The feed should be a dedicated read-only calendar share rather than a URL that
can modify calendar data. Its access can then be revoked independently.

Sources:

- [Homepage calendar widget and iCal integration](https://gethomepage.dev/widgets/services/calendar/)
- [Nextcloud iOS CalDAV setup](https://docs.nextcloud.com/server/latest/user_manual/en/groupware/sync_ios.html)
- [Nextcloud device-specific passwords](https://docs.nextcloud.com/server/latest/user_manual/en/session_management.html)

### Frequent external links

Start with:

- GitHub
- GitHub Pull Requests (`https://github.com/pulls`)
- YouTube
- Cloudflare Dashboard
- X
- Nextcloud Calendar

Use real brand icons and concise labels. This group is a launcher, so it does
not need descriptions or health checks. Add more links only after identifying
sites that are genuinely opened several times per week.

### Self-hosted applications

Group daily applications separately from operations.

**Applications**

- Home Assistant
- Nextcloud
- Paperless
- Miniflux

**Operations**

- Monitoring (Beszel or Grafana)
- Uptime Kuma
- Syncthing
- T3 Code

Homepage has native widgets for Nextcloud, Paperless-ngx, Miniflux, Home
Assistant, Uptime Kuma, Prometheus, Grafana, and Beszel. Most require API tokens.
Those tokens should be supplied through sops environment files rather than Nix
literals. Not every available widget should be enabled: each card should show
only information useful before opening the application, such as Paperless inbox
count or Miniflux unread count.

Sources:

- [Nextcloud widget](https://gethomepage.dev/widgets/services/nextcloud/)
- [Paperless-ngx widget](https://gethomepage.dev/widgets/services/paperlessngx/)
- [Miniflux widget](https://gethomepage.dev/widgets/services/miniflux/)
- [Home Assistant widget](https://gethomepage.dev/widgets/services/homeassistant/)
- [Uptime Kuma widget](https://gethomepage.dev/widgets/services/uptime-kuma/)

## Monitoring choice

### Option A: Beszel — recommended starting point

Beszel is explicitly designed as a lightweight server-monitoring product. It
provides historical CPU, memory, disk, disk I/O, network, temperature, Docker,
systemd, GPU, and SMART information plus alerts. Its hub and agent have native
NixOS modules in the repository's pinned nixpkgs. Homepage also has a native
Beszel widget.

Why it fits Kim:

- One primary NixOS homelab host.
- Docker and native systemd services are both present.
- SMART/NVMe visibility is desired.
- The user values a finished, attractive interface.
- It avoids designing and maintaining Grafana dashboards before the questions
  those dashboards need to answer are known.

Costs and caveats:

- Hub/agent pairing introduces a key that must be managed with sops.
- The Homepage widget currently requires a Beszel superuser credential, which
  is broader access than desirable; omitting the widget and linking to Beszel
  may be preferable.
- Beszel is less flexible than arbitrary PromQL and Grafana panels.

Sources:

- [Beszel overview and supported metrics](https://www.beszel.dev/guide/what-is-beszel)
- [Homepage Beszel widget](https://gethomepage.dev/widgets/services/beszel/)
- Pinned NixOS modules: `services.beszel.hub` and `services.beszel.agent`

### Option B: Prometheus and Grafana

Use this when the desired outcome includes custom metrics, long-term expansion
to more hosts, PromQL exploration, or dashboards maintained as code.

A minimal useful first deployment is:

- Prometheus listening only on loopback.
- Node exporter for machine-wide CPU, memory, filesystem, load, and network.
- systemd exporter restricted to important homelab units rather than every
  unit, limiting cardinality and visual noise.
- smartctl exporter for both NVMe drives.
- Grafana listening only on loopback and exposed through Tailscale Serve.
- One provisioned Prometheus datasource.
- One small, repository-owned `Kim Overview` dashboard.
- Passwordless authentication from Tailscale Serve identity headers.

Tailscale Serve strips spoofed identity headers and adds
`Tailscale-User-Login` for authenticated tailnet traffic. Grafana explicitly
supports authentication-proxy headers. Keep Grafana bound to loopback and let
Tailscale Serve be the sole entry point. Tailscale Services preserves the
client's Tailnet source address, so Grafana's auth-proxy whitelist must include
loopback and Tailscale's IPv4/IPv6 source ranges as one comma-separated string. This provides seamless login without anonymous access or
a second daily password prompt. Tailnet grants remain the outer authorization
boundary. Provisioned dashboards can stay read-only while the authenticated
user receives access to Grafana Explore.

Sources:

- [Tailscale Serve identity headers](https://tailscale.com/docs/features/tailscale-serve#identity-headers)
- [Grafana auth proxy](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/auth-proxy/)

The initial dashboard should answer:

1. Is CPU load or memory pressure unusual?
2. How quickly are `/` and `/srv` filling?
3. Are either NVMe drive unhealthy or overheating?
4. Which important systemd services are failed or repeatedly restarting?
5. Is network traffic abnormal?
6. When did Borg last complete successfully?

Do not begin with PostgreSQL, nginx, per-process, Loki, or application-specific
exporters. Add those only to answer an observed operational question.

Prometheus defaults to 15 days of retention when no policy is set. For this
single-host deployment, set both a bounded time and size policy, for example 30
days and 5 GiB, so metrics cannot fill the root filesystem. Prometheus documents
an average of roughly 1–2 bytes per sample and recommends leaving storage headroom.
Its TSDB is disposable operational history, not primary data; exclude it from
Borg instead of trying to copy its live WAL. Keep Grafana dashboards declarative
so Grafana's local database is also nonessential.

Grafana supports provisioning datasources and dashboards from version-controlled
files, which matches this repository's declarative ownership model.

Sources:

- [Prometheus node exporter guide](https://prometheus.io/docs/guides/node-exporter/)
- [Prometheus local storage and retention](https://prometheus.io/docs/prometheus/latest/storage/)
- [systemd exporter scope and filtering](https://github.com/prometheus-community/systemd_exporter)
- [smartctl exporter](https://github.com/prometheus-community/smartctl_exporter)
- [Grafana provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/)
- [Homepage Prometheus metric widget](https://gethomepage.dev/widgets/services/prometheusmetric/)

## Small custom tools worth considering

### Backup freshness metric

Neither a new dashboard nor a large exporter is needed to expose Borg status.
A small oneshot can write a node-exporter textfile metric after a successful
backup, for example:

```text
homelab_backup_last_success_timestamp_seconds 1785343200
```

Homepage can query it through its Prometheus metric widget, and Grafana can show
its age or alert when it becomes stale. This is a justified custom seam because
it exposes repository-specific operational state through a standard protocol.

### Frequently used link discovery

Do not build browser-history ingestion into the server. It would create a
privacy-sensitive sync pipeline for little benefit. Review the dashboard after
a week and add links manually; Homepage Quick Launch already searches them.

### Custom dashboard application

Not justified now. Reconsider only if there is a concrete cross-service workflow
that Homepage cannot express, such as a single action that coordinates Calendar,
Home Assistant, and agent tasks. Visual dissatisfaction alone should first be
addressed with Homepage's supported layout, icons, and theme.

## Other tools with plausible workflow value

These are not automatic recommendations:

- **Karakeep:** relevant only if links, PDFs, screenshots, and notes are being
  lost today. It has a modern UI, full-text search, browser extensions, an iOS
  app, archival, and a native NixOS module in pinned nixpkgs. Its own docs warn
  that it remains under heavy development.
- **Immich:** relevant only if replacing or supplementing iCloud Photos is an
  actual goal. Photo libraries substantially increase storage, backup, and
  public mobile-access responsibilities.
- **AdGuard Home/Pi-hole:** relevant only if network-wide DNS filtering is
  wanted. It makes Kim part of the network's critical DNS path.
- **ntfy:** relevant if Kuma, backup, SMART, and monitoring alerts currently
  have nowhere useful to go on iPhone.

Karakeep source: [official documentation and feature list](https://docs.karakeep.app/).

## Staged implementation

### Stage 1 — daily hub

- Install Nextcloud Calendar declaratively.
- Restructure Homepage into Frequent, Applications, and Operations.
- Add icons, theme, date/time, weather, search, and dot statuses.
- Keep Calendar as a link until its read-only iCal secret exists.
- Validate desktop and iPhone layout.

### Stage 2 — agenda and useful app summaries

- Create a read-only Nextcloud iCal share and store its URL with sops.
- Add the Homepage agenda.
- Add only high-value service widgets, starting with Paperless inbox and
  Miniflux unread counts.

### Stage 3 — monitoring

Choose one:

- Deploy Beszel hub/agent with SMART and systemd monitoring; or
- Deploy Prometheus, three exporters, Grafana, bounded retention, and one
  provisioned overview dashboard.

### Stage 4 — alerts and custom backup metric

- Export Borg freshness.
- Route only actionable failures to an iPhone notification destination.
- Add more metrics or tools only in response to observed needs.
