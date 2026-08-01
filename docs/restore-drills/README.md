# Homelab restore drill records

Owner: homelab operator. Cadence: quarterly after the first successful drill.
Store every completed record outside Kim as well as in this directory.

Do not create a success record without executing `docs/homelab-recovery.md` in
an isolated environment. Copy the template below to `YYYY-MM-DD.md`.

```markdown
# Homelab restore drill — YYYY-MM-DD

- Operator:
- Environment and isolation method:
- Borg repository/location:
- Archive:
- Git revision and dirty marker:
- NixOS/PostgreSQL/application versions:
- Started/finished/elapsed:
- External copy location for this record:

## Checks

- [ ] Independent recovery kit retrieved
- [ ] SOPS decrypted on a separate machine
- [ ] Off-site repository listed and extracted on a separate machine
- [ ] `homelab-backup-inspect` passed
- [ ] PostgreSQL restored into an isolated matching-major cluster
- [ ] Nextcloud representative files and calendar data opened
- [ ] Home Assistant config, integrations, automations, and recorder loaded
- [ ] Paperless exporter import, counts, files, search, Tika, and pending consume files verified
- [ ] Vaultwarden items, attachment, Send, and RSA identity verified
- [ ] Miniflux login/feed state verified
- [ ] Syncthing identity reviewed before one-peer reconnection
- [ ] Uptime Kuma monitors retained and notification test delivered
- [ ] Grafana/Prometheus disposable-state reprovisioning accepted
- [ ] Staged plaintext destroyed

## Failures and corrective actions

## Recovery-time observations

## Acceptance and next due date
```
