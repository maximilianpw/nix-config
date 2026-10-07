# Nixvim + Hjem migration ledger

Companion to `docs/nixvim-hjem-migration-plan.md`. Records the baseline, the
ownership ledger, what is implemented, and what still needs approval. The user
completed Joyce's rebuild on 2026-10-07. Joyce's editor is now cut over;
Hjem group 1 is also active and verified on Joyce. Kim and Cuno have not been migrated.

## Status by phase

| Phase | State |
| --- | --- |
| 0 Inventory, baseline, contract | Partial. Baseline and editor inventory done; the ledger below has per-group fields. Before any group transfers, expand that group to individual files, and verify Kim/Cuno chezmoi state. |
| 1 Standalone Nixvim candidate | Implemented: `nvim-candidate`, `nvim-vscode-candidate`, `checks.<system>.nvim-candidate`, passing on aarch64-darwin. Gate still open: Linux execution, parity of the final Home Manager-integrated package, interactive VS Code/Cursor, online AI/DAP/LSP checks. |
| 2 Editor cutover | Joyce rebuilt by user (2026-10-07). Applied only Cursor's reviewed executable-path change. Moved old config and shadowing helpers to `~/.local/state/nvim-migration-recovery/post-switch-20261007-114901`; original snapshot also retained. All four executables resolve through the Nix profile; live terminal startup and store-only runtime assertion passed. Interactive Cursor/AI/LSP/DAP acceptance remains open. Kim and Cuno unchanged. |
| 3 Hjem foundation | Linker lifecycle fixture done (`checks.<system>.hjem-lifecycle-regression`). Imported on Joyce only via `hjem = true` in `lib/hosts.nix` (2026-10-07). Joyce's first launch-agent activation verified: org.hjem.activate and org.nix.link-nix-apps exited 0, activation error log empty, deployed files verified. NixOS activation is untested. |
| 4 App files under Hjem | Group 1 (Joyce) active: 21 files verified against manifest sources (14 symlinks, 7 copies with mode 0644), no chezmoi overlap. CuaDriver resolves through Nix User Apps; Home Manager Apps is absent. Preserved 14 adjacent backups under `~/.local/state/nvim-migration-recovery/2026-10-07/hjem-group1/activation-backups-123029`. HM-owned files (yazi, Rectangle) and app-written files (Cursor, Zed, `.cursor`, `.plannotator`) are not in this group. |
| 5 Retire chezmoi | Not started. |

## Baseline (2026-10-07)

- Chezmoi source: `chezmoi source-path` = `~/.local/share/chezmoi`, commit
  `c1d6686`, clean. Joyce has chezmoi initialized; Kim and Cuno are unverified.
- Deployed drift: `.plannotator/config.json` differs from source in both
  directions (`chezmoi status` = `MM`). `~/.config/nvim` matches source; the
  deployed `lazy-lock.json` equals the source lock.
- Anomaly: `docs/research/mise-en-place-config-management.md` in the chezmoi
  repo is deployed to `~/docs/research/`. It looks accidental; do not migrate it.
- Old editor test suite (`test.sh`, non-CI mode): all pass except
  `architecture`, which failed only because macOS `/var` resolves to
  `/private/var` and the test compared unresolved paths. Fixed in the port by
  resolving the temp directory; no config behavior changed.
- Headless startup to `NVIM STARTED`, warm: old editor ~28 ms, candidate ~32 ms.

## Ownership ledger

Future owners are targets, not changes made. "HM exception" means Home Manager
keeps generating the file deliberately.

Columns follow the plan's ledger fields. Mode is the deployed file mode
(chezmoi `private_` = 0700 directories / 0600 files, `executable_` = 0755).
Mutability: *static* = never written by the app; *app-written* = the app
rewrites it; *?* = unchecked, must be resolved before transfer.

| Destination | Source / generator | Owner now → target | Scope | Mode | Mutability | Dependencies | Verification before transfer |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `~/.config/nvim/**` (72 files) | chezmoi `dot_config/nvim` | chezmoi → Nixvim (store; directory retired) | all hosts | 0644 | static (lazy wrote `lazy-lock.json`) | tooling.nix, dev-tools.nix formatters, `git` | `checks.*.nvim-candidate`, cutover checklist below |
| profile `nvim`, `vi`/`vim`/`vimdiff`, `EDITOR` | `modules/neovim.nix` (HM `programs.neovim`) | HM → Nixvim package in HM | all hosts | 0755 | static | `pkgs.unstable.neovim-unwrapped` today | executable provenance (`which nvim`), aliases, `$EDITOR` |
| `~/.local/bin/lazygit-nvim-edit` | chezmoi `private_dot_local/bin/executable_*` | chezmoi → Nix package | all hosts | 0755 in 0700 dir | static | `nvim` on PATH | Snacks lazygit edit/open-at-line; packaged binary on PATH |
| `~/.local/bin/herdr-shell` | same | chezmoi → Nix package | all hosts | 0755 in 0700 dir | static | herdr, jq, fleet, fish, hostname | new Herdr pane in "kim" and another workspace |
| `~/Library/Application Support/Cursor/User/settings.json` | chezmoi `private_Library/...` | chezmoi → Hjem (Darwin) | Joyce | 0600 in 0700 dirs | ? (Cursor writes settings) | `nvim-vscode` path at cutover | diff after Cursor edits a setting |
| `~/Library/.../Cursor/User/keybindings.json` | same | chezmoi → Hjem (Darwin) | Joyce | 0600 | ? | — | same |
| `~/.config/{direnv/direnv.toml,hunk,kitty,lazydocker,lazygit,ripgrep/config}`, `~/.config/starship.toml`, `~/.config/zed/keymap.json`, `~/.config/herdr/config.toml` | chezmoi `dot_config` | chezmoi → Hjem (shared) | all hosts | 0644 | static (Zed keymap ?) | herdr config calls `herdr-shell` | `chezmoi managed` vs Hjem manifest diff |
| `~/.config/glow/{glow.yml,catppuccin-mocha.json}` | chezmoi; `glow.yml` is a template | chezmoi → Hjem (rendered in Nix) | all hosts | 0644 | static | template data | rendered output equals `chezmoi cat` |
| `~/.config/vale/.vale.ini` | chezmoi `private_vale` | chezmoi → Hjem | all hosts | 0600 in 0700 dir | static | vale | `vale ls-config` |
| `~/.config/zed/settings.json` | chezmoi `private_settings.json` | chezmoi → Hjem or HM exception | all hosts | 0600 | ? (Zed writes settings) | — | check for app writes first |
| `~/.config/amp/plugins/*.ts` (7) | chezmoi | chezmoi → Hjem | all hosts | 0644 | static | Amp; `settings.json` already HM | Amp loads plugins |
| `~/.cursor/{permissions,sandbox}.json`, `~/.eslintrc.typescript.json`, `~/.oxlintrc.json`, `~/.prettierrc` | chezmoi | chezmoi → Hjem | all hosts | 0644 | ? (`.cursor` may be app-written) | — | content diff |
| `~/.plannotator/config.json` | chezmoi | chezmoi → undecided | all hosts | 0644 | app-written? (drift `MM` now) | — | resolve drift first |
| `~/docs/research/mise-en-place-config-management.md` | chezmoi (accidental) | chezmoi → none | all hosts | 0644 | static | — | remove from chezmoi target set |
| `~/.config/yazi/**` | `users/maxpw/yazi` via HM `xdg.configFile` (recursive) | HM → Hjem | all hosts | 0444 store links | static | yazi | manifest diff |
| `~/.config/rectangle/RectangleConfig.json` | HM `.text` | HM → Hjem | Joyce | 0444 | static (manual import into app) | Rectangle | — |
| `~/.config/{ghostty/config,gammastep/config.ini,uwsm/env,waybar/**,swaync/**,wlogout/*}` | HM; ghostty prepends login-shell command; wlogout css substitutes icon path | HM → Hjem | `linuxDesktop` only (none today) | 0444; Waybar scripts must stay executable | static | `settings.nix` shells, `pkgs.wlogout`, Waybar script commands | `linuxDesktop = true` fixture manifest diff; Stylix targets off |
| `~/.config/{helium,net.imput.helium}/NativeMessagingHosts/com.1password.1password.json` | HM generated JSON (1Password origins) | HM → Hjem or HM exception | `linuxDesktop` only | 0444 | static | `/run/wrappers/bin/1Password-BrowserSupport` | Helium ↔ 1Password integration |
| `~/.config/hypr/**`, generated `hypr/host.lua`, `hypr/hypridle.conf` | `users/maxpw/hyprland` via out-of-store links to the checkout (`lib/home-files.nix`); two generated children | HM → Hjem or explicit dev override | `linuxDesktop` only | links to checkout / 0444 | static, edited live in checkout | Hyprland flake input, hyprlock | edit workflow decision first |
| `~/.config/mise/config.toml`, `~/.config/jj/config.toml`, `~/.gnupg/gpg-agent.conf` | HM, `force = true` | HM exception | all hosts | 0444 | static | HM data | — |
| `~/.grok/config.toml`, `~/.pi/agent/{extensions,prompts,themes}`, agent configs | `agent-tools.nix`, `users/maxpw/agents` | HM exception until each writer contract is known | all hosts | mixed | some intentionally mutable | Pi resources are pi-config's | per-tool |
| `~/.config/cliproxyapi/client.json`, `~/.local/bin/{claude,codex,grok,opencode,...}` wrappers | `modules/{cliproxyapi,fleet}/home-manager.nix` | HM exception | per host | 0755 wrappers | static | cliproxyapi, Fleet | — |
| `.aws`, `.config/btop`, Zed conversations/themes/prompts, Amp `settings.json*` | chezmoi ignore set | unmanaged | — | — | app-written / private | — | never swept into Git |

## Editor implementation notes

- **Loader:** lz.n through Nixvim (`plugins.lz-n`). Spec files keep their data
  (`opts`, `keys`) and use `before`/`after`/`beforeAll`; `VeryLazy` became
  `DeferredUIEnter`. `lua/config/plugins.lua` lists every spec per profile, and
  `tests/registry.lua` fails if a file is unregistered or still uses
  lazy.nvim-only fields. lazy.nvim and its lockfile/update checker are gone.
- **Plugin versions:** 45 plugins are built from the exact commits that were in
  `lazy-lock.json`. `blink.cmp`, `fff.nvim`, `nvim-treesitter` and
  `nvim-treesitter-textobjects` come from Nixvim's package set so Nix builds
  their native code and grammars together. These are newer than the old lock:
  blink.cmp 1.10.2, fff.nvim 0.10.3, and nvim-treesitter main `910fdf6`. Neovim
  0.12.5 matches today's editor.
- **Two packages:** `terminal` and `vscode` share all Lua. The VS Code package
  ships only mini, flash, nvim-treesitter (+textobjects, grammars) and
  ts-comments; a test asserts nothing else is on its packpath.
- **Purity:** `impureRtp = false` at this Nixvim pin still left
  `stdpath("data")/site` and the XDG site directories on `runtimepath` and
  `packpath`. Seeded test files there caught it. The init now keeps only store
  paths, plus the vscode-neovim extension runtime when `g:vscode` is set: the
  extension prepends it with `--cmd` before init and later requires
  `vscode.internal` from it. The VS Code test bootstraps a stand-in runtime the
  same way.
- **Native components:** Blink uses the Rust matcher with downloads disabled and
  fails visibly otherwise. fff's library and all 23 Treesitter parsers (plus
  inherited query languages) come from the store. Parser installation at runtime
  was removed; `:TSInstall` output, if used manually, goes to
  `stdpath("cache")/treesitter-manual-installs`.
- **Approved exception (Supermaven):** the plugin is Nix-managed; its `sm-agent`
  engine is still downloaded by the plugin into `~/.supermaven` on first use.
  nixpkgs does not package it, and its download URL comes from Supermaven's API.
  Tab/Ctrl+L behavior is covered by `tests/plugins.lua`. The offline check never
  starts Supermaven or Amp's IDE server; verify both interactively after cutover.
- **Host dependencies:** gitsigns and obsidian.nvim need `git` on PATH (the
  check supplies it). Shared formatters stay in `dev-tools.nix`.
- **Not carried over:** the dashboard "Lazy" entry and the lualine lazy-updates
  component (lazy.nvim no longer exists). `config/dap/js.lua` no longer probes Mason or
  lazy.nvim paths; it uses `js-debug` from PATH.

## Editing workflow (contract)

The deployed editor is immutable store content; the checkout is the only
editable source.

1. Edit `users/maxpw/neovim/config/**` (`<leader>fc` now opens this directory,
   in VS Code too) or the Nix files beside it.
2. Try it: `nix run .#nvim-candidate -- <file>` (isolated state via
   `NVIM_APPNAME=nvim-candidate`; never reads `~/.config/nvim`).
3. Test it: `nix build .#checks.aarch64-darwin.nvim-candidate`
   (`x86_64-linux` on Linux). Linux builds run without network.
4. Update: `make update` moves the core inputs, including `nixpkgs-unstable`
   (Neovim and the native plugins blink.cmp, fff.nvim, nvim-treesitter),
   `nixvim` and `hjem`. It then moves every pinned Lua plugin
   (`make update-nvim-plugins`). `make update-all` does the same. For a single
   plugin: `scripts/nvim-plugin-pins.sh NAME [REV]`. Then run step 3 and the
   `hjem-lifecycle-regression` check before rebuilding.
5. Deploy: only after cutover, via the normal rebuild.

Until cutover, chezmoi still deploys the live editor. Do not edit
`~/.local/share/chezmoi/dot_config/nvim` meanwhile, or port the edit here too.

The Hyprland checkout-backed reload loop is unchanged. Choose before desktop
cutover: immutable Hjem files plus rebuild, or an explicit development
override.

## Hjem findings (pin `2b15569`)

From reading the modules and exercising the CLI at this pin. The regression
fixture (`scripts/tests/hjem-lifecycle-fixture.sh`) asserts only the safety
properties the configuration relies on; the hazards below are recorded here, not
pinned, so an upstream fix does not fail the check. Re-check them when moving
the `hjem` input:

- **nix-darwin import is not inert.** It always adds two launch agents:
  `hjem-activate`, and `link-nix-apps`, which links every app in the per-user
  profile into `~/Applications/Nix User Apps`. It also requires
  `system.primaryUser`. The activation script kicks agents with `|| true`, so a
  successful switch does not prove files were linked; check
  `/var/tmp/hjem-activate.{out,err}` and the state in
  `~/Library/Application Support/Hjem`. Decide whether the app links are wanted
  next to Home Manager's before importing on Joyce.
- **NixOS import adds `hjem.target`** to `multi-user.target` even with no users.
- **Collisions are backed up, not refused**, even with clobber off: an unmanaged
  file becomes `.backup-<name>`. The backup slot is single-use, so a second
  collision overwrites an earlier backup. Before any transfer, snapshot targets
  outside `$HOME` and confirm no `.backup-*` names exist.
- **Failures are not all-or-nothing.** Conflicts found before linking (a file
  where a parent directory is needed) change nothing. Later failures leave
  partial changes. If the state file cannot be written, new links exist but the
  recorded state is stale. If Hjem refuses a removal, other removals in the same
  run still happen. Hjem refuses to delete a path it managed that now belongs to
  someone else, and refuses to delete a user-edited copy. Each case fails every
  activation until the cause is fixed; re-running then converges. Recovery
  means inspecting the targets, not trusting the state file.
- **Re-applying a manifest that still lists a path takes it back** from another
  owner, keeping the other owner's link in `.backup-<name>`. Hence the two-stage
  handoff: remove the path from Hjem's manifest and activate, then enable the new
  owner (and the reverse).
- **Runtime does not validate manifests:** `hjem internal activate` and
  `hjem manifest validate` only warn about invalid entries. Activating one
  deactivates previously managed files. The modules' build-time `cue vet` is the
  guard; the regression check asserts it still rejects them.

## Editor cutover procedure (Phase 2; needs approval per host)

1. Snapshot `~/.config/nvim`, `~/.local/share/nvim/{site,lazy}` and
   `~/.local/state/nvim` to a recovery directory outside `$HOME/.config` and the
   runtimepath. Keep permissions; no secrets are expected there.
2. Exclude `.config/nvim` and the two `.local/bin` helpers from chezmoi for that
   host only, via template data or a hostname-scoped ignore. Render the result
   (`chezmoi managed`, `chezmoi diff`) before applying.
3. Replace `programs.neovim` with the Nixvim terminal package (appName `nvim`,
   same aliases and `EDITOR`), add `nvim-vscode`, `lazygit-nvim-edit` and
   `herdr-shell` to the profile, and drop the `nvim/init.lua` force-disable.
   Point Cursor's `neovimExecutablePaths.darwin` at `nvim-vscode`.
4. Rebuild, then check: `which nvim` resolves into the profile;
   `:lua =vim.api.nvim_list_runtime_paths()` lists store paths only; LSP attach,
   completion, Supermaven suggestions, Amp, DAP and neotest work; VS Code uses
   the reduced editor.
5. Roll back by reverting the commit and rebuilding, re-enabling the chezmoi
   entries, and restoring the snapshot. A Nix generation rollback alone does not
   restore files chezmoi removed.

## Hjem on Joyce: group 1

- **App linking:** Hjem's `link-nix-apps` agent is the only linker for apps in
  the per-user profile (`~/Applications/Nix User Apps`). `users/maxpw/hjem/darwin.nix`
  disables Home Manager's `linkApps`/`copyApps` and asserts they stay off, so
  `~/Applications/Home Manager Apps` disappears at the switch. nix-darwin's
  system apps (`/Applications/Nix Apps`) and Homebrew apps are a different set
  and are untouched.
- **Files:** each file is linked individually (several apps keep state beside
  their config). Amp plugins are copies, because Amp scans its plugin
  directory. `glow.yml` is rendered in Nix from the old chezmoi template.
  Content matches the deployed files apart from one stripped trailing space in
  `kitty.conf`.
- **Handoff:** chezmoi's `.chezmoiignore` excludes the same 21 paths for
  `joyce`; Kim and Cuno still get them from chezmoi. On the switch, Hjem moves
  each chezmoi-deployed file to `.backup-<name>` beside it and links its own.
  Snapshot: `~/.local/state/nvim-migration-recovery/2026-10-07/hjem-group1`.
- **After the switch, verify:** `/var/tmp/hjem-activate.err` is empty and
  `/var/tmp/hjem-activate.out` shows the links;
  `~/Library/Application Support/Hjem/manifest.json` lists the 21 files; each
  target is a link (Amp plugins: a file); `~/Applications/Nix User Apps`
  contains CuaDriver and `Home Manager Apps` is gone. Then move the
  `.backup-*` files into the snapshot directory. A second collision would
  overwrite them.
- **Rollback:** set `hjem = false` for Joyce and rebuild. That removes the
  agents, but not Hjem's links, so delete them using the state manifest. Then
  drop the Joyce block from `.chezmoiignore` and run `chezmoi apply` for those
  paths, or restore the snapshot.

## App-written files (checkout-backed)

`users/maxpw/modules/app-config.nix` links five app-written files straight to
`users/maxpw/app-config/` in the checkout (Home Manager `mkOutOfStoreSymlink`):
Cursor settings and keybindings (macOS),
`.cursor/permissions.json`, `.cursor/sandbox.json`, and
`.plannotator/config.json`. The apps write through the link, `git diff` shows
their changes, and recovery is from Git rather than a Nix generation. The live
contents were copied, including Plannotator's own `reviewAnalysis` addition.
The scan found no credentials, and the chezmoi repo already published them.

- **Ownership:** `users/maxpw/hjem/default.nix` asserts that no enabled Home
  Manager file shares a path with a Hjem file. Chezmoi manages no files on
  Joyce now; the stray `~/docs/research` note is simply no longer managed.
- **At the switch:** Home Manager moves each existing file to `<name>.backup`
  and links the checkout file. Snapshot:
  `~/.local/state/nvim-migration-recovery/2026-10-07/app-config`.
- **Post-switch verified (2026-10-07):** all seven live symlinks resolve to
  their intended checkout files. Each adjacent `.backup` is byte-identical to
  the checkout file: no late edits were lost. Chezmoi reports zero managed
  files on Joyce. Backups remain intact.
- **Cursor settings save verified (2026-10-07):** after the user changed a
  setting in Cursor, the live settings.json remained a symlink to the checkout,
  live/source bytes matched, and contents differed from the pre-switch backup.
  This confirms writing through the link for that settings-save operation.
- **Zed removed:** Zed is not installed, so its two migrated configs were
  dropped from the list. The next switch removes the two Home Manager links;
  the pre-switch `.backup` files in `~/.config/zed` stay.
- **Remaining scope:** Plannotator, Cursor keybindings and
  Cursor security-settings save behavior are not established by the Cursor
  settings test. A file whose app replaces the link must leave this list.

## macOS apps from Nix

`users/maxpw/modules/packages/darwin-apps.nix` holds self-contained, notarized
apps that moved off Homebrew. Hjem's agent links them into
`~/Applications/Nix User Apps`. Launch Services registers them at their
store path; Spotlight does not index the symlinks.

- **Obsidian 1.14.4** (`packages/obsidian.nix`, official DMG). The signature
  verifies and Gatekeeper accepts it as notarized. User confirmed the Nix app
  works on 2026-10-07. At final handover Homebrew already reported the cask
  uninstalled and `/Applications/Obsidian.app` was absent; the Nix app and
  existing settings directory remained. Removed the cask declaration so the
  next rebuild will not reinstall it. No zap was run.
- **Kept on Homebrew:** Yaak (nixpkgs is a year behind), Legcord (no Darwin
  package), Freelens (not packaged).

## Open items

- Linux execution of `nvim-candidate` and `hjem-lifecycle-regression` (no Linux
  builder here; evaluation passes).
- Hjem module activation on a disposable NixOS VM (headless, WSL, reboot, user
  units vs lingering) and on a disposable macOS account (launch agent,
  logged-out behavior).
- Kim and Cuno: is chezmoi initialized, and which hosts get the editor first?
- Hyprland/desktop edit workflow, Waybar script packaging, the Stylix target
  audit in a `linuxDesktop = true` fixture.
- Interactive checks a headless test cannot cover: LSP sessions, DAP adapters,
  Supermaven/Amp online behavior, VS Code integration.
