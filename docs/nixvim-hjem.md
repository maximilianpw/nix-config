# Nixvim and Hjem

Nixvim owns Neovim and Hjem owns hand-authored app files; the ownership table
is in [configuration ownership and recovery](config-ownership-and-recovery.md).
Every host enables both through the `hjem` flag in `lib/hosts.nix`; Home
Manager selects Nixvim from the same flag so the two stay in step.

## Rollout state

- Joyce and Kim are cut over (2026-10-07). Their pre-cutover snapshots are under
  `~/.local/state/nvim-migration-recovery/` on each host.
- Cuno's live cutover is pending. Before its first migrated rebuild, follow the
  host cutover below.
- Chezmoi is not retired. On Kim it still owns two legacy Zed configs and a
  stray research note; `scripts/dev/chezmoi.sh` covers what remains.

## Editing the editor

The deployed editor is immutable store content; the checkout is the only
editable source.

1. Edit `users/maxpw/neovim/config/**` (`<leader>fc` opens it, in VS Code too)
   or the Nix files beside it.
2. Try it: `nix run .#nvim-candidate -- <file>` (isolated state via
   `NVIM_APPNAME=nvim-candidate`).
3. Test it: `nix build .#checks.<system>.nvim-candidate`.
4. Update: `make update` moves `nixpkgs-unstable` (Neovim, blink.cmp, fff.nvim,
   nvim-treesitter), `nixvim` and `hjem`, then every pinned Lua plugin
   (`make update-nvim-plugins`). For one plugin:
   `scripts/dev/nvim-plugin-pins.sh NAME [REV]`. Then rerun step 3 and the
   `hjem-lifecycle-regression` check before rebuilding.

Constraints the tests enforce:

- lz.n loads every plugin; `tests/registry.lua` fails if a spec file is
  unregistered or uses lazy.nvim-only fields.
- `terminal` and `vscode` packages share all Lua; the VS Code package ships only
  mini, flash, nvim-treesitter (with textobjects and grammars) and ts-comments.
- The runtime path contains store paths only (plus the vscode-neovim runtime
  under `g:vscode`). Parsers and native libraries come from the store; manual
  `:TSInstall` output goes to `stdpath("cache")/treesitter-manual-installs`.
- Approved exception: Supermaven's `sm-agent` engine is downloaded by the
  plugin into `~/.supermaven` on first use. nixpkgs does not package it.

Not covered by headless checks: LSP sessions, DAP adapters, Supermaven/Amp
online behavior and VS Code integration. Verify those interactively.

## Host cutover and rollback

1. Snapshot `~/.config/nvim`, `~/.local/share/nvim/{site,lazy}` and
   `~/.local/state/nvim` outside `~/.config` and the runtime path.
2. Exclude `.config/nvim`, the two `.local/bin` helpers and the Hjem-managed
   files from chezmoi for that host; render (`chezmoi managed`, `chezmoi diff`)
   before applying. Retire any shadowing helpers in `~/.local/bin`.
3. Rebuild. Check that `which nvim` resolves into the profile and
   `:lua =vim.api.nvim_list_runtime_paths()` lists store paths only.
4. Move Hjem's `.backup-*` collision files into the snapshot directory; a second
   collision would overwrite them.

Roll back by reverting the commit and rebuilding, re-enabling the chezmoi
entries and restoring the snapshot. A generation rollback alone does not
restore files chezmoi removed. Turning `hjem` off removes Hjem's agents but not
its links: delete them using the state manifest.

## Hjem hazards

Recorded at pin `2b15569`. `tests/hjem-lifecycle-fixture.sh` asserts only the
safety properties this configuration relies on, so an upstream fix does not
fail it. Re-check these when moving the `hjem` input:

- **nix-darwin import is not inert.** It adds the `hjem-activate` and
  `link-nix-apps` launch agents and requires `system.primaryUser`. Activation
  kicks agents with `|| true`, so a successful switch does not prove files were
  linked; check `/var/tmp/hjem-activate.{out,err}` and
  `~/Library/Application Support/Hjem`.
- **NixOS import adds `hjem.target`** to `multi-user.target` even with no users.
- **Collisions are backed up, not refused**, even with clobber off: an unmanaged
  file becomes `.backup-<name>`, and the single backup slot is overwritten by a
  second collision.
- **Failures are not all-or-nothing.** Later failures leave partial changes and
  can leave the state file stale. Hjem refuses to delete a path that now
  belongs to someone else or a user-edited copy; each case fails every
  activation until fixed. Recover by inspecting targets, not the state file.
- **Re-applying a manifest that still lists a path takes it back** from another
  owner. Hand off in two stages: remove the path from Hjem and activate, then
  enable the new owner (and the reverse).
- **Runtime does not validate manifests.** The modules' build-time `cue vet` is
  the guard, and the regression check asserts it still rejects invalid ones.

On Joyce, Hjem's `link-nix-apps` agent is the only linker for per-user profile
apps (`~/Applications/Nix User Apps`); `users/maxpw/hjem/darwin.nix` keeps
Home Manager's `linkApps`/`copyApps` off.

## App-written files

`users/maxpw/modules/app-config.nix` links app-written files (Cursor settings
and keybindings, `.cursor/{permissions,sandbox}.json`,
`.plannotator/config.json`) straight to `users/maxpw/app-config/` with
`mkOutOfStoreSymlink`. Apps write through the link, `git diff` shows their
changes, and recovery is from Git. A file whose app replaces the link instead
of writing through it must leave this list. `users/maxpw/hjem/default.nix`
asserts that no Home Manager file shares a path with a Hjem file.
