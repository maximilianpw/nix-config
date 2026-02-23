---
name: add-package
description: Add a Nix package to the correct module based on category
disable-model-invocation: true
---

# Add Package Skill

Add a new package to the nix-config. The user will provide a package name as an argument.

## Determine the correct location

Based on the package type, add it to the right file:

- **CLI/terminal tools** (bat, ripgrep, fd, etc.) -> `users/maxpw/modules/packages/terminal-tools.nix`
- **Dev tools, languages, formatters, cloud tools** -> `users/maxpw/modules/packages/dev-tools.nix`
- **Linux desktop/GUI apps** (Wayland tools, GUI editors, etc.) -> `users/maxpw/modules/packages/linux-desktop.nix`
- **macOS GUI apps** -> `users/maxpw/darwin.nix` (as a Homebrew cask in the `casks` list)
- **System-level packages** (drivers, kernel modules, services) -> `machines/<hostname>.nix`
- **Fonts** -> `users/maxpw/modules/fonts.nix`

## Steps

1. Search nixpkgs for the package name: `nix search nixpkgs#<name>` to confirm it exists and get the exact attribute name
2. For macOS cask apps, verify the cask name at https://formulae.brew.sh/
3. Determine which category file the package belongs in
4. Read the target file to understand the existing structure
5. Add the package to the appropriate list, maintaining alphabetical order within the list
6. Run `alejandra` on the modified file to format it
7. Optionally run `nix flake check --no-build` to validate
