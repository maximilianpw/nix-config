# Bootstrap Guide

How to get this config running on a machine, from "blank hardware" to "daily
driver". There are three scenarios, from most to least work:

1. [Brand-new NixOS machine from an ISO](#scenario-1-new-nixos-machine-from-an-iso)
2. [New (or wiped) Mac](#scenario-2-new-or-wiped-mac)
3. [Reinstalling an existing host / repo already cloned](#scenario-3-existing-host)

In all cases the finishing move is the same: `./scripts/bootstrap.sh`, which
checks prerequisites, enables flakes, sets up the repo and `/etc/nixos`
symlink, verifies the host exists in the flake, verifies the sops age key
(NixOS and Darwin), and offers to run the first rebuild. Run
`./scripts/bootstrap.sh --dry-run` to see what it would do.

> **The one dangerous gap to know about (NixOS):** the user password is a
> sops secret. If the age key is not at `/var/lib/sops-nix/key.txt` before
> the first rebuild, the user is created with **no password** — you're locked
> out. Both `bootstrap.sh` and `nixos-rebuild.sh` check for this and refuse
> to proceed, but do the key step early and deliberately.

## Scenario 1: New NixOS machine from an ISO

The bootstrap script does **not** install NixOS — these first steps are
manual, from the installer ISO.

### 1. Install NixOS

Boot the ISO, then partition and install. Two options:

- **Manual/graphical install**: use the installer as usual. Keep the
  generated `hardware-configuration.nix` — you'll need it in step 3.
- **Disko**: adapt `machines/hardware/main-pc-disko.nix` for the new
  machine's disks and run it from the ISO:

  ```bash
  sudo nix --experimental-features "nix-command flakes" run \
    github:nix-community/disko -- --mode disko ./your-disko.nix
  sudo nixos-install
  ```

Create your user during install (or in the minimal config) so you can log in.

### 2. First boot: clone the repo

Clone over **HTTPS** — the machine has no GitHub SSH key yet:

```bash
nix-shell -p git
git clone https://github.com/maximilianpw/nix-config.git ~/nix-config
cd ~/nix-config
```

### 3. Add the new host to the flake (skip if reinstalling a known host)

The flake only knows `main-pc`, `wsl`, and `macbook-pro-m1`. A new machine
needs (see [Adding a new host](#adding-a-new-host)):

1. `machines/<hostname>.nix` + hardware config under `machines/hardware/`
2. A `mkSystem` entry in `flake.nix`
3. A login→host mapping line in `scripts/lib/host-detect.sh`

Commit and push these from an existing machine if possible, so the new
machine can just pull a working config.

### 4. Place the sops age key (prevents lockout)

The key lives in 1Password (vault: Personal, item: "sops nixos"). Full
details in `secrets/README.md`; the short version:

```bash
mkdir -p ~/.config/sops/age
nix-shell -p _1password-cli --run \
  'eval $(op signin); op item get "sops nixos" --fields password --reveal' \
  >> ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

sudo mkdir -p /var/lib/sops-nix
sudo cp ~/.config/sops/age/keys.txt /var/lib/sops-nix/key.txt
sudo chmod 600 /var/lib/sops-nix/key.txt
sudo chown root:root /var/lib/sops-nix/key.txt
```

### 5. Bootstrap and rebuild

```bash
cd ~/nix-config
./scripts/bootstrap.sh --skip-clone
```

Say yes to the initial rebuild at the end (or run `make rebuild` later).
The first build is large; it uses the committed, CI-tested `flake.lock`
(pass `--update` only if you deliberately want fresh inputs).

### 6. Post-install checklist

Config is now reproduced; **data and credentials are not**. After the first
successful rebuild:

- [ ] Sign in to the 1Password app and enable the SSH agent (unlocks git
      pushes and `fleet` SSH)
- [ ] Switch the repo remote to SSH:
      `git remote set-url origin git@github.com:maximilianpw/nix-config.git`
- [ ] `sudo tailscale up` — join the tailnet (fleet/remote-dev relies on it)
- [ ] Accept Syncthing device pairings from an existing machine (personal data)
- [ ] Restore anything needed from Borg backups
- [ ] Verify secrets decrypted: `ls -la /run/secrets/`

## Scenario 2: New (or wiped) Mac

1. **Xcode Command Line Tools** (provides real `git`):

   ```bash
   xcode-select --install
   ```

2. **Determinate Nix installer** (the config assumes it: `nix.enable = false`
   in `machines/macbook-pro-m1.nix`, daemon managed by Determinate):

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```

3. **Homebrew** — nix-darwin manages casks/brews but does not install
   Homebrew itself; the first `darwin-rebuild` fails without it:

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

4. **Clone and bootstrap** (HTTPS — no SSH keys yet):

   ```bash
   git clone https://github.com/maximilianpw/nix-config.git ~/nix-config
   cd ~/nix-config
   mkdir -p ~/.config/sops/age
   nix-shell -p _1password-cli --run \
     'eval $(op signin); op item get "sops nixos" --fields password --reveal' \
     >> ~/.config/sops/age/keys.txt
   chmod 600 ~/.config/sops/age/keys.txt
   ./scripts/bootstrap.sh --skip-clone
   ```

   Note: macOS Nix settings (caches, trusted-users) live in
   `/etc/nix/nix.custom.conf`, managed by the darwin config — not
   `nix.settings`.

5. **Post-install**: create and upload a GitHub SSH key if needed, switch the
   repo remote to SSH, start Tailscale, and pair Syncthing.

## Scenario 3: Existing host

Repo already cloned (or host already in the flake — e.g. reinstalling
main-pc):

```bash
cd ~/nix-config
./scripts/bootstrap.sh --skip-clone   # or `make bootstrap`
```

On NixOS, place the system age key first (Scenario 1, step 4 above). On
Darwin, place the user age key first (Scenario 2, step 4 above). The script
checks and will tell you if either key is missing.

## Adding a new host

1. **Machine config**: create `machines/<hostname>.nix` (boot, hardware,
   services). Generate hardware config on the machine with
   `nixos-generate-config --show-hardware-config` and store it under
   `machines/hardware/<hostname>.nix` (see `machines/main-pc.nix` for how
   main-pc imports its hardware files).
2. **Flake entry** in `flake.nix`:

   ```nix
   nixosConfigurations.<hostname> = mkSystem "<hostname>" {
     system = "x86_64-linux";
     user = "maxpw";
     # darwin = true;  # for Macs (use darwinConfigurations.<name>)
     # wsl = true;     # for WSL
   };
   ```

3. **Host detection**: add the login→host mapping in
   `scripts/lib/host-detect.sh` (shared by `bootstrap.sh` and
   `nixos-rebuild.sh` — one edit covers both).
4. **Secrets** (NixOS only): no per-host key setup needed — all hosts share
   the age key from 1Password. If you want per-host keys instead, add the
   host as a recipient in `.sops.yaml` and run
   `sops updatekeys secrets/secrets.yaml`.
5. Commit, push, and run the bootstrap on the new machine.

For WSL specifically, see `docs/wsl-setup.md` (`make wsl` builds the import
tarball).

## Day-to-day commands

After bootstrap (see `make help` for the full list):

```bash
make rebuild      # Format, switch via nh (generation diff), clean old generations
make build        # Build without switching
make update       # Update shared flake inputs (skips Hyprland & NixOS-only inputs)
make update-all   # Update all flake inputs
make generations  # List system generations
make rollback     # Roll back to previous generation
make lint         # statix, deadnix, format check
make info         # Show system information
```

The `nr` shell alias runs `make -C ~/nix-config rebuild`. Rebuild does
**not** auto-commit — commit manually (pre-commit hook lints).

## Troubleshooting

### Flakes not working

Ensure experimental features are enabled:

```bash
nix config show | grep experimental
```

### Locked out after first NixOS rebuild (no password)

The rebuild ran without the sops age key. Boot the previous generation from
the bootloader menu (or use root/installer access), place the key at
`/var/lib/sops-nix/key.txt` (Scenario 1, step 4), and rebuild again.

### /etc/nixos is a directory

Back it up first, then symlink:

```bash
sudo mv /etc/nixos /etc/nixos.backup
sudo ln -sfn ~/nix-config /etc/nixos
```

### Build failures

```bash
# View the last rebuild's output (created on first rebuild)
cat ~/nix-config/nixos-switch.log

# Validate the flake without building
nix flake check --no-build
```

### Secrets not decrypting

See the troubleshooting section in `secrets/README.md` — usually the age key
is missing from `/var/lib/sops-nix/key.txt` or doesn't match `.sops.yaml`.

## Support

- Main [README.md](README.md) for configuration details
- `lib/mksystem.nix` for how hosts are wired
- NixOS manual: https://nixos.org/manual/
- nix-darwin: https://github.com/nix-darwin/nix-darwin
