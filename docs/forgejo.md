# Forgejo on Kim

Forgejo runs at `https://git.liger-shilling.ts.net/` through Tailscale
Serve. Its HTTP listener binds only to `127.0.0.1:19010`. Git over SSH uses
`forgejo@kim.liger-shilling.ts.net` on Kim's existing port 22, which Fleet
opens only on `tailscale0`. Registration is closed; an administrator creates
accounts deliberately.

The NixOS Forgejo module uses the supported `forgejo-lts` package and Kim's
socket-only PostgreSQL. Forgejo stores repositories, attachments, LFS data,
configuration, and generated signing secrets under `/srv/forgejo`. Borg also
archives the `forgejo` database and the runner registration files under
`/var/lib/forgejo-runner-registration`. Do not put repository data or tokens in
Nix source.

## First activation

Apply the Kim configuration only through the normal reviewed rebuild process.
After activation, confirm `forgejo.service` and `forgejo-runner.service` are
active and `forgejo-runner-register.service` completed successfully. If
Tailscale requires approval for the new `svc:git` service, approve it before
testing the web UI or runner connection. Check the web health endpoint through
the tailnet and verify that `forgejo@kim.liger-shilling.ts.net` is reachable by
SSH.

Create the first administrator from the version-matched CLI:

```sh
sudo -u forgejo forgejo-admin admin user create \
  --username maxpw --email '<your-email>' \
  --admin --random-password --must-change-password
```

The command prints a temporary password. Save it in 1Password and change it
at the first login. Create a private test repository and clone it over HTTPS
and SSH before moving important repositories. Add passkeys or two-factor
authentication to the administrator account.

## Actions runner

The `forgejo-runner` system service runs on Kim as an unprivileged user. Its
only label is `docker`, which starts jobs in rootless Podman containers based
on `node:22-bookworm`. The runner is limited to one concurrent job. Job
containers have a 4 GiB memory and two CPU limit, cannot mount the Podman
socket, and have no host execution label or allowed host volumes. Container
images and caches live under `/srv/forgejo-runner`; that directory is
disposable and is not part of the Forgejo recovery point.

The registration service generates a 40-character secret on first start,
stores it with a restrictive group permission, and registers the same runner
idempotently in Forgejo. The runner reads that secret through systemd
credentials. Neither the secret nor its runtime configuration is put in the
Nix store. The runner is registered globally, so keep account registration
closed and grant repository write access only to people trusted to run CI on
Kim. Container jobs still consume Kim's resources and can reach network
services; do not use this runner for untrusted contributions.

To verify it, add `.forgejo/workflows/smoke.yml` to the private test repository:

```yaml
on: [push]
jobs:
  smoke:
    runs-on: docker
    steps:
      - run: node --version
```

Push a commit and confirm the job succeeds. If the runner is offline, inspect
`journalctl -u forgejo-runner.service -u forgejo-runner-register.service` and
`systemctl --user -M forgejo-runner@ status podman.socket`. The rootless socket
must exist at `/run/user/<runner-uid>/podman/podman.sock`; Kim's rootful Docker
socket must remain inaccessible to the runner user.

## Recovery

Follow [Kim's recovery runbook](homelab-recovery.md) to select and stage one
archive. Keep `forgejo-runner.service`, `forgejo-runner-register.service`, and
`forgejo.service` stopped. Restore the `forgejo` PostgreSQL database, the full
`/srv/forgejo` tree, and `/var/lib/forgejo-runner-registration` from that same
archive. Preserve ownership and restrictive modes. Use the archived Forgejo
package version before allowing its database migrations.

Start Forgejo on isolated tailnet ingress. Verify the existing administrator
can sign in, open a private repository, and clone it over HTTPS and SSH.
Then start the registration service and runner, confirm the registered UUID
matches the archived runner, and run a harmless container job. If runner
registration files were lost, the registration service generates a new
identity, but old runner entries may remain in Forgejo until an administrator
removes them. Keep the staged archive untouched until these checks pass.
