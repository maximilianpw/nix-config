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

### 2. Add your public key to .sops.yaml

Edit `../.sops.yaml` and replace `YOUR_AGE_PUBLIC_KEY_HERE` with the public key from step 1.

### 3. Create your secrets file

```bash
# Create the secrets file from template
cp secrets.yaml.example secrets.yaml

# Edit it with sops (this will encrypt it)
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

The password is automatically decrypted and used by NixOS at build time. The decrypted secret is placed in `/run/secrets/maxpw-password` and is only readable by root.

## Important Security Notes

- **NEVER** commit `~/.config/sops/age/keys.txt` (your private key) to git
- Only commit encrypted `.yaml` files, never plaintext secrets
- The `.sops.yaml` file contains public keys only - safe to commit
- The age private key is backed up in **1Password** (vault: Personal, item: "sops nixos")
- Keep the 1Password account secure with a strong master password and 2FA

## Rotating Secrets

To change the password:

```bash
nix-shell -p sops --run "sops secrets.yaml"
# Edit the password, save and exit
# Rebuild your system
```

## Setting up a New NixOS Machine

When installing NixOS on a new system, you need to place the age key before rebuilding:

```bash
# 1. Retrieve the key from 1Password
mkdir -p ~/.config/sops/age
nix-shell -p _1password age --run 'echo "# created: $(date -Iseconds)" > ~/.config/sops/age/keys.txt && op item get "sops nixos" --fields password --reveal >> ~/.config/sops/age/keys.txt'
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

## Troubleshooting

If you get decryption errors:

1. Make sure your age private key is in both:
   - `~/.config/sops/age/keys.txt` (for local editing)
   - `/var/lib/sops-nix/key.txt` (for system decryption)
2. Verify the public key in `.sops.yaml` matches your private key:
   ```bash
   age-keygen -y ~/.config/sops/age/keys.txt
   # Should match the key in .sops.yaml
   ```
3. Ensure the secrets file was encrypted with the correct key
4. If key is missing, retrieve it from 1Password (see "Setting up a New NixOS Machine" above)
