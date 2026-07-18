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

## Recovery layers

The configuration repository recreates software and service definitions, not
personal data. Recovery currently has these layers:

- The admin Age identity is stored outside the repo in 1Password.
- `main-pc`'s SSH host identity is a second SOPS recipient, allowing that live
  host to decrypt if the admin identity is temporarily unavailable.
- Borg writes application-consistent exports/dumps and file data to the local
  removable repository. This includes a quiesced Home Assistant config archive
  and its PostgreSQL recorder dump. Use `sudo borg-job-main list`, then
  `sudo borg-restore-main <archive> <existing-empty-directory> [path ...]` to
  stage a restore without overwriting live data. Follow the version-matched
  [Paperless restore drill](paperless.md) for its supported exporter format.
- Syncthing replicates selected user data but is not a versioned backup or a
  substitute for Borg.

The host-key SOPS recipient is not disaster recovery for loss of `main-pc`.
These external pieces still require a provider/location choice and credentials;
they cannot safely be invented in this public configuration:

1. Generate an independent offline Age identity, store it outside both
   `main-pc` and 1Password, add only its recipient to `.sops.yaml`, and run
   `sops updatekeys secrets/secrets.yaml`.
2. Configure an encrypted off-site Borg repository and test a restore from a
   separate machine. Keep its passphrase and recovery instructions outside the
   backed-up host.
3. Configure an external dead-man/backup-failure notification destination. A
   check running only on `main-pc` cannot report total host or network loss.

Test recovery quarterly: list archives, run Borg consistency checks, extract a
small sample to an empty staging directory, validate the Home Assistant config
archive, a PostgreSQL dump, and the Paperless export, and confirm the offline
Age identity can decrypt a copy of the SOPS file. Complete the Paperless import
and application checks described in its restore drill rather than treating the
presence of an export as sufficient.
