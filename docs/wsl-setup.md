# Cuno NixOS-WSL Setup Guide

## Prerequisites

- Windows 10 (2004+) or Windows 11
- The `nixos.wsl` import image produced by `make wsl`

## 1. Enable WSL

Open PowerShell as Administrator:

```powershell
wsl --install --no-distribution
```

Reboot if prompted.

## 2. Import the image

```powershell
wsl --import Cuno $env:USERPROFILE\Cuno C:\path\to\nixos.wsl
wsl -d Cuno
```

## 3. Clone and apply config

Inside the WSL shell:

```bash
git clone <your-repo-url> ~/nix-config
cd ~/nix-config
sudo nixos-rebuild switch --flake .#cuno
```

`make wsl` writes the image to `.artifacts/nixos.wsl` and verifies it is
non-empty after running the NixOS-WSL builder.

Log out and back in for shell/user changes to take effect:

```bash
exit
```

```powershell
wsl -d Cuno
```

## 4. Enrol Cuno in Fleet

Cuno runs its own `tailscaled` and `sshd`; Windows is not used as the network
owner for Fleet. Inside Cuno:

```bash
sudo tailscale up --hostname cuno
ssh-keygen -t ed25519 -f ~/.ssh/fleet_ed25519 -C "fleet cuno"
cat ~/.ssh/fleet_ed25519.pub
```

Replace Cuno's `client = null` in `lib/hosts.nix` with its public key, stable
IPv4/IPv6 Tailscale addresses, and `identityFile = ".ssh/fleet_ed25519"`.
Apply the normalized trust set to Kim and Joyce. Cuno's generated SSH aliases
then select `~/.ssh/fleet_ed25519` automatically.

WSL must be running for Cuno to accept inbound connections. Verify:

```bash
systemctl is-active sshd tailscaled
fleet list
```

## 5. Set as default WSL distro (optional)

```powershell
wsl --set-default Cuno
```

## Ongoing usage

After initial setup, rebuilds auto-detect WSL:

```bash
cd ~/nix-config
make rebuild
```

## Troubleshooting

**"Cuno" not appearing in `wsl -l -v`:**
Re-run the import command. Make sure the image path is correct.

**Permission errors on rebuild:**
The first rebuild must use `sudo nixos-rebuild switch --flake .#cuno` directly. `make rebuild` works for subsequent rebuilds.

**Slow first rebuild:**
Normal. Nix needs to fetch/build derivations not included in the image. Subsequent rebuilds are incremental.
