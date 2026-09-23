# Secrets Management with sops-nix

This directory contains encrypted secrets managed by [sops-nix](https://github.com/Mic92/sops-nix).

The age private key for decrypting secrets is stored in **1Password** for secure backup and easy access across machines.

## Initial Setup

### 1. Get an age key

**Retrieve existing key from 1Password**

```bash
# Install 1Password CLI and age
nix-shell -p _1password-cli age

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

## Usage

NixOS secrets are decrypted by system sops-nix under `/run/secrets`. Darwin
and WSL use the user age identity for the CLIProxyAPI client token and Home
Manager user secrets. `github-ssh-private-key` is the GitHub authentication key used by
non-desktop NixOS hosts; desktop hosts use the 1Password SSH agent instead.

### Adding or rotating a single value

Write one value without opening an editor or echoing it:

```bash
nix-shell -p sops --run 'sops set --value-stdin secrets/secrets.yaml "[\"linear-api-key\"]"'
```

Paste the value as JSON (a quoted string), then commit `secrets/secrets.yaml`
before rebuilding another machine.

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
- `kim`, derived from Kim's ED25519 SSH host key. sops-nix reads the
  private half directly from `/etc/ssh/ssh_host_ed25519_key`, so the server can
  keep decrypting secrets if the copied admin key is unavailable.

The host recipient is an operational fallback, not independent disaster
recovery: the host key is on the same root disk as the system. Loss of both the
machine and 1Password would still make the secrets, including the Borg
passphrase, unrecoverable.

The offline recovery identity is tracked in the
[homelab backlog](../docs/homelab-backlog.md#disaster-recovery). Once its public
recipient is in `.sops.yaml`, rewrap the data key with
`nix-shell -p sops --run 'sops updatekeys secrets/secrets.yaml'`.

## Rotating Secrets

To change the password:

```bash
nix-shell -p sops --run "sops secrets/secrets.yaml"
# Edit the password, save and exit
# Rebuild your system
```

## Setting up a New Machine

When installing NixOS on a new system, you need to place the age key before rebuilding:

```bash
# 1. Retrieve the key from 1Password
mkdir -p ~/.config/sops/age
nix-shell -p _1password-cli age --run 'echo "# created: $(date -Iseconds)" > ~/.config/sops/age/keys.txt && eval $(op signin) && op item get "sops nixos" --fields password --reveal >> ~/.config/sops/age/keys.txt'
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

On Darwin and WSL, only the user key is needed. System sops-nix uses it for the
CLIProxyAPI client token, and Home Manager uses it for user secrets:

```bash
mkdir -p ~/.config/sops/age
nix-shell -p _1password-cli age --run 'echo "# created: $(date -Iseconds)" > ~/.config/sops/age/keys.txt && eval $(op signin) && op item get "sops nixos" --fields password --reveal >> ~/.config/sops/age/keys.txt'
chmod 600 ~/.config/sops/age/keys.txt
```

## Troubleshooting

If you get decryption errors:

1. Make sure your age private key is in both:
   - `~/.config/sops/age/keys.txt` (for local editing and Darwin/WSL system and Home Manager secrets)
   - `/var/lib/sops-nix/key.txt` (for standard NixOS system decryption)
2. Verify the public key in `.sops.yaml` matches your private key:
   ```bash
   age-keygen -y ~/.config/sops/age/keys.txt
   # Should match the key in .sops.yaml
   ```
3. Ensure the secrets file was encrypted with the correct key
4. If key is missing, retrieve it from 1Password (see "Setting up a New Machine" above)
