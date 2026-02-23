---
name: rebuild
description: Run the NixOS/Darwin rebuild to apply configuration changes
disable-model-invocation: true
---

# Rebuild Skill

Run the system rebuild after making Nix configuration changes.

## Steps

1. Run `alejandra .` in the repo root (`~/nix-config`) to format all Nix files
2. Run `nix flake check --no-build` to validate the flake
3. Show the user the `git diff` of changed `.nix` files for review
4. Ask the user if they want to proceed with the full rebuild (`make -C ~/nix-config rebuild`)
5. If yes, run `make -C ~/nix-config rebuild` and report the result
6. If the rebuild fails, show the relevant error output and suggest fixes
