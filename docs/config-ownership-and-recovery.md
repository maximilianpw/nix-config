# Configuration Ownership and Recovery

## Ownership boundary

Nix/Home Manager and chezmoi are intentionally separate. Do not declare the
same destination in both systems.

| Concern | Owner | Review/apply path |
| --- | --- | --- |
| OS, services, firewall, mounts, users | NixOS / nix-darwin | `make build`, then `make rebuild` |
| Packages, shells, editor executables, SSH/fleet | Home Manager in this repo | system rebuild |
| Neovim Lua, formatter/linter policy, app content | chezmoi source | `make chezmoi-preview`, then `make chezmoi-apply` |
| Encrypted machine/application secrets | sops-nix in this repo | edit with `sops`; system rebuild |

Home Manager deliberately disables management of Neovim's `init.lua`; chezmoi
owns that tree. Home Manager provides the binaries the editor and its plugins
execute. `scripts/chezmoi.sh` formalizes initialization, no-write validation,
preview, and interactive apply without silently overwriting a new machine.

Chezmoi's `private_` filename prefix sets restrictive file permissions. It does
**not** encrypt file contents. Secrets belong in sops, a password manager, or a
chezmoi encrypted source file; plaintext credentials must never be committed.

## Homelab state classes

Every service state artifact has exactly one owner:

| State class | Owner | Recovery rule |
| --- | --- | --- |
| Declarative configuration | Git + NixOS | Rebuild the archived revision |
| Encrypted secret | SOPS or external password manager | Decrypt at runtime and independently test key recovery |
| Mutable primary data | Application database/files | Back up consistently and restore with the matching application version |
| Disposable state | Reprovisioned cache/history | Exclude deliberately and record the accepted loss |
| External control-plane state | Cloudflare, Tailscale, or another provider | Manage as code or document ownership and audit drift |

The normalized records in `lib/homelab-inventory.nix` enforce the local state,
backup, storage, monitoring, and endpoint classifications. Mutable UI state is
not declarative merely because an activation hook could replay commands.

## Recovery layers

The configuration repository recreates software and service definitions, not
personal data. Recovery currently has these layers:

- The admin Age identity is stored outside the repo in 1Password.
- Kim's SSH host identity is a second SOPS recipient, allowing that live
  host to decrypt if the admin identity is temporarily unavailable.
- Borg writes application-consistent exports/dumps and file data to the local
  removable repository. This includes a quiesced Home Assistant config archive
  and its PostgreSQL recorder dump. Use `sudo borg-job-main list`, then
  `sudo borg-restore-main <archive> <existing-empty-directory> [path ...]` to
  stage a restore without overwriting live data. Use
  `sudo homelab-backup-inspect <archive>` for read-only member and metadata
  validation, then follow the complete [homelab recovery runbook](homelab-recovery.md)
  and version-matched [Paperless restore drill](paperless.md).
- Syncthing replicates selected user data but is not a versioned backup or a
  substitute for Borg.

### Portable Vaultwarden exports

Run `vault-backup` interactively on a Syncthing client to create dated,
password-protected JSON exports under `~/Sync/Recovery/Vaultwarden`. The
command synchronizes the vault first, exports the personal vault and every
accessible organization with one confirmed recovery passphrase, and rejects
the result unless it has the expected encrypted, password-protected envelope.
The recovery passphrase must remain available without Vaultwarden.

Kim retains received Syncthing deletions for 30 days, and `~/Sync` is also part
of the Borg archive. These portable exports supplement the server-level backup;
they do not include attachments or Sends, which remain covered by the
PostgreSQL dump and complete `/var/lib/bitwarden_rs` archive.

The host-key SOPS recipient is not disaster recovery for loss of Kim.
These external pieces still require a provider/location choice and credentials;
they cannot safely be invented in this public configuration:

1. Generate an independent offline Age identity, store it outside both
   Kim and 1Password, add only its recipient to `.sops.yaml`, and run
   `sops updatekeys secrets/secrets.yaml`.
2. Configure an encrypted off-site Borg repository and test a restore from a
   separate machine. Keep its passphrase and recovery instructions outside the
   backed-up host.
3. Configure an external dead-man/backup-failure notification destination. A
   check running only on Kim cannot report total host or network loss.

Test recovery quarterly using `docs/homelab-recovery.md`: list archives, run
Borg consistency checks, extract only to empty staging directories, restore the
major applications in isolation, and confirm the offline Age identity can
decrypt a copy of the SOPS file. Store the dated drill result outside Kim as
well as in the repository.
