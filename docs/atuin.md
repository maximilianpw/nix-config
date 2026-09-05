# Private shell history sync

Kim runs Atuin on loopback port 19007 with local PostgreSQL. Tailscale Serve
publishes `https://atuin.liger-shilling.ts.net`; there is no public ingress or
host firewall opening. Kim and Joyce use this endpoint for Nushell, Fish, and
Bash. Ctrl+R searches history from both machines; up-arrow stays unchanged.
Atuin's AI shortcut is disabled; this setup is only for history search and sync.

## Deploy and enroll once

These are operator steps on the real machines, not commands for an orb or CI.
Build/review and rebuild Kim and Joyce using the usual repository workflow,
then open fresh shells. No account, password, or encryption key is provisioned
by Nix.

1. In the Tailscale admin console, create/approve the `svc:atuin` HTTPS service
   on TCP 443 and Kim's advertisement as required by the tailnet policy. Allow
   only your intended clients/identity. This external policy is not managed by
   this repository. Verify `curl --fail https://atuin.liger-shilling.ts.net/`
   works on both machines before enrolling. Tailscale reachability does not
   replace Atuin's own account login.
2. Registration is closed by default. On Kim, temporarily open it using
   `sudo systemctl edit --runtime --drop-in=atuin-enrollment.conf atuin.service`
   and enter:

   ```ini
   [Service]
   Environment=ATUIN_OPEN_REGISTRATION=true
   ```

   Run `sudo systemctl restart atuin.service`. Keep this window brief: anyone
   allowed to reach the service can register while it is open.
3. In Kim's normal user shell, run `atuin register -u maxpw -e YOUR_EMAIL`.
   Enter the password at the prompt; do not pass passwords as command arguments.
   Run `atuin key` **privately**, and save the key with the account password in
   1Password. Never paste its output into an agent conversation, logs, or Git.
4. Close registration immediately, even if enrollment failed:

   ```sh
   sudo rm /run/systemd/system/atuin.service.d/atuin-enrollment.conf
   sudo systemctl daemon-reload
   sudo systemctl restart atuin.service
   ```

   Only remove this enrollment-specific file, not unrelated overrides. Confirm
   `systemctl show atuin.service --property=Environment` includes
   `ATUIN_OPEN_REGISTRATION=false` (inspect locally; do not share environment
   output). Reboot also removes the runtime override.
5. On Joyce, run `atuin login -u maxpw`, supplying the same password and
   encryption key at the prompts. Do not register a second account. Run
   `atuin sync` on each machine.

Existing shell history is **not imported automatically**. If desired, review
it for secrets first, then run `atuin import auto` from each shell whose history
you want to retain, followed by `atuin sync`.

## Verify and use

In an interactive Kim shell, run `echo atuin-kim-sync-check`, then `atuin sync`.
On Joyce, run `atuin sync` and search for `atuin-kim-sync-check` with Ctrl+R.
Repeat in the other direction with a distinct harmless marker. Confirm up-arrow
still uses the shell's normal history behavior. Verify an unauthorized tailnet
identity cannot reach the service and registration is closed before considering
setup complete.

Automatic sync is checked during shell activity, with a five-minute interval;
it is not an always-running background replication service. `atuin sync` forces
a sync now. If Kim or Tailscale is unavailable, local history remains usable;
sync can catch up when connectivity returns.

Built-in secret filtering and a leading-space exclusion are enabled. Neither
guarantees every secret is caught. Avoid literal secrets in commands and do not
sync client SQLite databases or key files with Syncthing. The server stores
encrypted history, but account metadata remains sensitive. The encryption key
is separate from the login password and is required to decrypt history on a
replacement client.

## Recovery

Follow [the Atuin recovery contract](homelab-recovery.md#atuin). Back up the
client encryption key independently in 1Password; a server database restore
alone cannot recover it. Home Manager owns the client config, while Atuin owns
its mutable local history, session, and key files outside Git/Nix.
