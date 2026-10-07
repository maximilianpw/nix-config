# Vite+ packaging

Vite+ comes from the community flake
[`ryoppippi/nix-vite-plus`](https://github.com/ryoppippi/nix-vite-plus), not a
repo-local derivation. `flake.nix` imports its overlay and Home Manager installs
`pkgs.vite-plus` for Joyce, Kim, and Cuno. `flake.lock` pins the revision; its
nixpkgs input follows this repository's `nixpkgs-unstable`.

## Why this flake

At the selected revision `af16f6183aec0717d8975ee858c910ab43babee6`:

- [Release sources](https://github.com/ryoppippi/nix-vite-plus/blob/af16f6183aec0717d8975ee858c910ab43babee6/sources.json)
  pin Vite+ 1.0.0.
- [The package](https://github.com/ryoppippi/nix-vite-plus/blob/af16f6183aec0717d8975ee858c910ab43babee6/package.nix)
  includes the native CLI and the npm toolchain, exports `vp`, `vpx`, and `vpr`,
  patches Linux native dependencies, and fixes template-copy permissions.
- [CI](https://github.com/ryoppippi/nix-vite-plus/actions/runs/37301379567)
  passed for that revision. Its build matrix covers x86-64 Linux, ARM64 Linux,
  and Apple Silicon macOS.

Other candidates inspected:

- [`naitokosuke/vp-nix`](https://github.com/naitokosuke/vp-nix): packages the
  npm-based CLI, but its inspected HEAD was still Vite+ 0.2.6.
- [`Myxogastria0808/vite-plus-nixpkg`](https://github.com/Myxogastria0808/vite-plus-nixpkg):
  inspected HEAD was 0.1.20.
- [`why-reproductions-are-required/vite-plus-nix-demo`](https://github.com/why-reproductions-are-required/vite-plus-nix-demo):
  uses a nixpkgs fork at 0.2.1 and documents requiring a project-local package
  for JavaScript-delegating commands.

## Runtime ownership and updates

Home Manager sets `VP_NODE_MANAGER=no`, `VP_PM_MANAGER=no`, and
`VP_SELF_SETUP_NO_MODIFY_PATH=1`. These keep first-run setup from taking over
Nix-managed runtimes or editing shell profiles. Vite+ still creates mutable
user configuration and fallback shims in its own directories; those shims are
not added to PATH automatically. Existing saved management preferences are not
reset. Project-local toolchain versions remain independently managed.

Update with `nix flake update vite-plus`, then verify with
`nix build .#vite-plus --no-link` and the usual repository evaluation checks.
Do not use `vp upgrade` to update a Nix-owned installation.

Local verification of the selected flake passed on macOS: package build,
`vp --version`, `vp toolchain --global`, `vp fmt`, `vp lint`, `vp build`, and
`vpr`/`vpx` help, using a disposable home/project and the session variables
above. Linux package execution was not tested locally; upstream CI covers it.
