# NixOS-WSL Setup Guide

## Prerequisites

- Windows 10 (2004+) or Windows 11
- The `nixos-wsl.tar.gz` tarball built from main-pc

## 1. Enable WSL

Open PowerShell as Administrator:

```powershell
wsl --install --no-distribution
```

Reboot if prompted.

## 2. Import the tarball

```powershell
wsl --import NixOS $env:USERPROFILE\NixOS C:\path\to\nixos-wsl.tar.gz
wsl -d NixOS
```

## 3. Clone and apply config

Inside the WSL shell:

```bash
git clone <your-repo-url> ~/nix-config
cd ~/nix-config
sudo nixos-rebuild switch --flake .#wsl
```

Log out and back in for shell/user changes to take effect:

```bash
exit
```

```powershell
wsl -d NixOS
```

## 4. Set as default WSL distro (optional)

```powershell
wsl --set-default NixOS
```

## Ongoing usage

After initial setup, rebuilds auto-detect WSL:

```bash
cd ~/nix-config
make rebuild
```

## Troubleshooting

**"NixOS" not appearing in `wsl -l -v`:**
Re-run the import command. Make sure the tarball path is correct.

**Permission errors on rebuild:**
The first rebuild must use `sudo nixos-rebuild switch --flake .#wsl` directly. `make rebuild` works for subsequent rebuilds.

**Slow first rebuild:**
Normal. Nix needs to fetch/build derivations not included in the tarball. Subsequent rebuilds are incremental.
