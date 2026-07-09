# Secrets Management with sops-nix

This directory contains encrypted secrets managed by [sops-nix](https://github.com/Mic92/sops-nix).

The age private key for decrypting secrets is stored in **1Password** for secure backup and easy access across machines.

## Initial Setup

### 1. Get an age key

**Retrieve existing key from 1Password**

```bash
# Install 1Password CLI and age
nix-shell -p _1password age

# Authenticate with 1Password
eval $(op signin)

# Retrieve the age private key
mkdir -p ~/.config/sops/age
echo "# created: $(date -Iseconds)" > ~/.config/sops/age/keys.txt
op item get "sops nixos" --fields password --reveal >> ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# Display your public key to verify
age-keygen -y ~/.config/sops/age/keys.txt
```

### 2. Verify your public key in .sops.yaml

Confirm the key printed in step 1 matches the `admin_max` recipient in
`../.sops.yaml`. If intentionally rotating it, update the public recipient and
run `sops updatekeys secrets/secrets.yaml` while the old key is still available.

### 3. Create your secrets file

```bash
# Create/edit the secrets file with sops (encrypts on save using .sops.yaml rules)
nix-shell -p sops --run "sops secrets.yaml"
```

### 4. Add your password hash

In the sops editor, replace `YOUR_HASHED_PASSWORD_HERE` with your actual password hash.

To generate a new password hash:

```bash
mkpasswd -m sha-512
```

### 5. Commit the encrypted file

```bash
git add secrets.yaml .sops.yaml
git commit -m "Add encrypted secrets"
```

## Usage

NixOS secrets are decrypted by system sops-nix under `/run/secrets`. Darwin
user secrets are decrypted by Home Manager sops-nix under the user account.
`github-ssh-private-key` is the GitHub authentication key used by non-desktop
NixOS hosts; desktop hosts use the 1Password SSH agent instead.

## Important Security Notes

- **NEVER** commit `~/.config/sops/age/keys.txt` (your private key) to git
- Only commit encrypted `.yaml` files, never plaintext secrets
- The `.sops.yaml` file contains public keys only - safe to commit
- The age private key is backed up in **1Password** (vault: Personal, item: "sops nixos")
- Keep the 1Password account secure with a strong master password and 2FA

## Recipient and disaster-recovery status

The encrypted file currently has two recipients:

- `admin_max`, whose private age key is stored in 1Password and is used for
  editing and bootstrapping machines.
- `main_pc`, derived from main-pc's ED25519 SSH host key. sops-nix reads the
  private half directly from `/etc/ssh/ssh_host_ed25519_key`, so the server can
  keep decrypting secrets if the copied admin key is unavailable.

The host recipient is an operational fallback, not independent disaster
recovery: the host key is on the same root disk as the system. Loss of both the
machine and 1Password would still make the secrets, including the Borg
passphrase, unrecoverable.

The remaining manual recovery task is to create an offline age key, store its
private half outside both main-pc and 1Password (for example on encrypted
removable media held separately), add only its public recipient to `.sops.yaml`,
and rewrap the data key:

```bash
# After adding the offline public recipient to .sops.yaml:
nix-shell -p sops --run 'sops updatekeys secrets/secrets.yaml'
```

Keep an independently secured offline copy of the Borg passphrase as part of
the same recovery kit; the backups are needed in exactly this failure mode.

## Rotating Secrets

To change the password:

```bash
nix-shell -p sops --run "sops secrets.yaml"
# Edit the password, save and exit
# Rebuild your system
```

## Setting up a New Machine

When installing NixOS on a new system, you need to place the age key before rebuilding:

```bash
# 1. Retrieve the key from 1Password
mkdir -p ~/.config/sops/age
nix-shell -p _1password age --run 'echo "# created: $(date -Iseconds)" > ~/.config/sops/age/keys.txt && eval $(op signin) && op item get "sops nixos" --fields password --reveal >> ~/.config/sops/age/keys.txt'
chmod 600 ~/.config/sops/age/keys.txt

# 2. Place it in the system location for sops-nix
sudo mkdir -p /var/lib/sops-nix
sudo cp ~/.config/sops/age/keys.txt /var/lib/sops-nix/key.txt
sudo chmod 600 /var/lib/sops-nix/key.txt
sudo chown root:root /var/lib/sops-nix/key.txt

# 3. Verify the key is in place
sudo ls -la /var/lib/sops-nix/key.txt
# Should show: -rw------- 1 root root

# 4. Now you can rebuild
sudo nixos-rebuild switch --flake .#MACHINE_NAME

# 5. Verify secrets are decrypted
ls -la /run/secrets/maxpw-password
```

On Darwin, only the user key is needed:

```bash
mkdir -p ~/.config/sops/age
nix-shell -p _1password age --run 'echo "# created: $(date -Iseconds)" > ~/.config/sops/age/keys.txt && eval $(op signin) && op item get "sops nixos" --fields password --reveal >> ~/.config/sops/age/keys.txt'
chmod 600 ~/.config/sops/age/keys.txt
```

## Troubleshooting

If you get decryption errors:

1. Make sure your age private key is in both:
   - `~/.config/sops/age/keys.txt` (for local editing and Darwin Home Manager secrets)
   - `/var/lib/sops-nix/key.txt` (for system decryption)
2. Verify the public key in `.sops.yaml` matches your private key:
   ```bash
   age-keygen -y ~/.config/sops/age/keys.txt
   # Should match the key in .sops.yaml
   ```
3. Ensure the secrets file was encrypted with the correct key
4. If key is missing, retrieve it from 1Password (see "Setting up a New NixOS Machine" above)
