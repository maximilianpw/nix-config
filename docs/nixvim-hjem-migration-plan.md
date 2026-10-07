# Consolidate editor and application configuration with Nixvim and Hjem

Status: independently reviewed by Fable 5.1 and GPT-6 Astra; findings incorporated by the plan author. Phases 0 and 1 and the Phase 3 linker fixture are implemented; no host has been activated or changed. Progress, baseline, ownership ledger, Hjem findings and the cutover procedure are in `docs/nixvim-hjem-ledger.md`. Live ownership transfers still need per-host approval.

## Objective and decision

Consolidate the chezmoi-managed editor and app content into nix-config. Adopt Nixvim for Neovim and Hjem as the unified owner of hand-authored application files, including existing Linux desktop files currently deployed by Home Manager. Retain Home Manager for packages, shells, and useful program/service integrations. Preserve ordinary Lua, CSS, JSON, TOML, and other native configuration files where translating them into Nix adds no value.

This is an architectural preference, not a claim that Home Manager cannot do the same file placement. The lower-disruption alternative is Home Manager files plus Nix-provided plugins loaded by lazy.nvim. Do not silently substitute that alternative for the requested target. Reconsider the target only on concrete failed acceptance gates.

## Ownership after migration

| Concern | Owner |
| --- | --- |
| OS, login/session integration, portals, graphics, users, system services | NixOS / nix-darwin |
| User packages, shells, retained program/service integrations and their generated files | Home Manager |
| Neovim executable/configuration/plugins and editor-specific dependencies | Nixvim, integrated through Home Manager |
| Hand-authored shared, Linux-desktop, macOS and host-specific app files | Hjem |
| Secrets | Existing SOPS / external runtime secret tooling; never ordinary store sources |
| Pi resources | pi-config, unchanged |
| Application-written state | Application-owned writable locations, explicitly excluded from static deployment |

Exactly one owner per destination, including parent directories: a linked directory cannot also contain separately managed child paths. Hjem is a system module, not a Home Manager submodule. Retained HM-generated files are intentional exceptions, not an arbitrary second static-file layer.

## Verified starting points

- `lib/hosts.nix` owns host capabilities: kim is headless Linux, cuno is WSL, joyce is Darwin. All currently have `linuxDesktop = false`. Do not enable a desktop merely to exercise this migration.
- Joyce's login name is `max-vev`, while shared configuration lives under `users/maxpw`; Linux users are `maxpw`. Derive identity and home paths, do not hardcode the Linux example for all hosts.
- `lib/mksystem.nix` composes system and HM modules and supplies `currentSystemUser`, `currentSystemUserDir`, `isDarwin`, `isWSL`, and `isLinuxDesktop`.
- `users/maxpw/modules/neovim.nix` supplies unstable Neovim and supporting tools and disables HM's `nvim/init.lua` ownership. Shell-visible tools also live in `modules/packages/dev-tools.nix`.
- Chezmoi source is currently `/Users/max-vev/.local/share/chezmoi`; discover it with `chezmoi source-path` rather than embedding that path in implementation.
- Its Neovim init bootstraps lazy.nvim, uses a lockfile beside init, and selects a smaller plugin set in VS Code through lazy conditions. Preserve VS Code behavior.
- Earlier Fable inspection reported 30 lazy plugin-spec files, eight headless tests, native/runtime build hooks, and roughly 36 non-editor files. Recount and verify rather than treating those counts as a migration manifest.
- `users/maxpw/modules/xdg.nix` already deploys Yazi, Rectangle, Ghostty, Waybar, swaync, wlogout, Hyprland and generated integration files. It uses `lib/home-files.nix` for writable checkout-backed Hyprland links and generates host.lua and hypridle.conf.
- Hyprland itself must continue to come from the existing flake input. Hjem does not replace its NixOS session/portal integration.
- `.chezmoiignore` is templated for macOS Library paths. AWS/employer data, btop and various app-written files are excluded; Amp settings already belong to HM. Ignore rules are evidence to preserve, not permission to sweep the home directory into Git.
- `make check-nvim` checks tool availability; it does not replace behavioral editor tests. `make check-linux` evaluates Linux checks; it does not execute built Linux tests.

## Phase 0 — Inventory, baseline, and migration contract

1. Inventory only managed source files and current HM declarations. Do not copy the whole source checkout or any home tree. Record source, destination, current owner, future owner, platform/capability, mutability, permissions, generator, dependencies, and verification for each entry.
2. Classify ignored/stale files, private-prefixed files, secrets, native scripts and executable bits, macOS Library paths, templates, and app-rewritten files. Private permissions are not encryption. Record excluded paths without reading secret contents.
3. Capture existing source revisions, local changes, deployed-file drift and editor lock versions. Preserve unrelated edits in both repositories; resolve any divergent deployed configuration explicitly before migration.
4. Run the existing editor tests and tooling checks as a baseline. Record failures without broad unrelated repairs. Enumerate plugins, event/ft/key/conditional loading, runtime compilation/downloads, and existing behavior assertions.
5. Decide and document the editing contract: immutable store-backed deployed configuration by default; fast standalone editor builds/tests; an explicit optional development override only if needed. Checkout-backed links are not reproducible deployment and must not be presented as such. Do not silently discard Hyprland's current direct-edit/reload workflow.
6. Create a source-to-destination ownership ledger and rollback procedure before any live transfer.

Gate: complete ledger, known baseline, explicit writable exceptions, and agreed editor/desktop development workflow. No blanket clobber/force adoption.

## Phase 1 — Standalone Nixvim candidate, current editor untouched

1. Add a pinned, compatible Nixvim input and a reusable editor module under `users/maxpw/neovim/` (final layout should follow repo conventions). Check current upstream compatibility requirements; do not blindly make its nixpkgs follow the repository's stable input. Document any separate package set and unfree-plugin handling.
2. Expose an opt-in standalone candidate package such as `packages.<system>.nvim-candidate` for Darwin and Linux. Keep current default editor and chezmoi ownership unchanged.
3. Separate immutable editor configuration from writable cache/data/state. Run the candidate with isolated XDG directories and, where compatible, NVIM_APPNAME, ensuring it neither loads the old user config nor overwrites normal plugin/session state. Test VS Code integration separately.
4. Port declarative options, keymaps and plugin setup where useful; retain complex functions as ordinary Lua. Do not bulk-wrap the old lazy bootstrap and claim plugin management has migrated.
5. Explicitly map initialization order and event semantics: options -> bigfile -> keymaps -> autocmds, plugin setup dependencies, deferred loading, directory opening, and VS Code gating. Evaluate the pinned Nixvim loader support; choose eager loading or supported lazy loading by behavior and measured startup impact, not by automatic field translation.
6. Nix owns plugin sources, native libraries and Treesitter grammars. Replace runtime bootstrap, updates, downloads and compilation for the reproducible core. Preserve Supermaven inline AI autocomplete. The user approved a narrow runtime-download exception for its autocomplete engine if reproducible packaging is impractical; see review decisions below. Verify fff native library, blink fuzzy backend, Treesitter API/grammar compatibility and missing plugin packaging on both architectures. Preserve individual commit pins where needed; Nix does not prohibit them.
7. Preserve LSP, formatter, linter, debugger, test runner and terminal tool availability without competing wrappers or duplicate server startup. Keep shared CLI tools available outside the editor.
8. Port existing headless tests to assert behavior rather than obsolete lazy implementation details. Add a fresh-state startup check with no runtime installation/network fetching. Where possible enforce network denial, not just absence of logs.

Gate: candidate builds on aarch64-darwin and x86_64-linux; existing behavioral coverage passes; no old configuration contamination or runtime dependency installation in the reproducible core; any optional proprietary-agent exception is explicitly approved and excluded from the offline-core claim; native components work.

## Phase 2 — Editor parity and authorized ownership transfer

Exercise on representative small and large files: 100/150/200KB bigfile thresholds; completion; Treesitter; LSP attach/diagnostics; formatting and light/heavy lint triggers; navigation/search; Git; UI; directory opening; sessions; AI plugin loading without exposing credentials; neotest; Go/JS/Rust DAP where available; VS Code reduced mode. Compare startup and large-file responsiveness with the baseline. Mark unavailable integrations unverified rather than substituting a startup smoke test.

Provide a short build/run/test workflow for routine edits that does not require a system switch. Nixvim's generated-config smoke check supplements, not replaces, existing tests and user-facing checks.

After explicit activation approval for each real host:

1. Preserve a recoverable snapshot of the old managed targets outside Git/Nix store, with permissions retained; no broad home backup or secret printing.
2. Exclude the Neovim destination from chezmoi's active deployment before installing the new owner. Retain source/history for rollback. Ensure other hosts still using chezmoi cannot lose their editor through shared source changes; use a coordinated per-host transition policy.
3. Replace the old HM Neovim declaration with Nixvim's HM integration and preserve editor aliases/defaults. Ensure the candidate and default do not race over init.lua, executables or wrappers.
4. Activate, run smoke/parity checks, and verify executable/config provenance.
5. Remove lazy lock/update machinery from the new configuration only after plugin-version ownership is demonstrably in Nix; do not delete historical recovery sources yet.

Gate: Joyce plus each targeted Linux host has validated editor ownership and recovery. No host activation is implied by permission to implement/build.

## Phase 3 — Hjem foundation and disposable lifecycle trial

1. Add a pinned Hjem input. Import the appropriate NixOS/nix-darwin module through system composition; derive user/home/capabilities from existing inventory and account definitions.
2. Define shared, Linux-desktop and Darwin file modules under a clear user-owned application-config directory. Keep native app files native. Carry generated host-specific content and package paths across explicitly.
3. Before taking over real files, test the selected Hjem/linker version in disposable homes/state directories on Darwin and Linux: initial creation, update, unmanaged collision refusal, file-to-directory conflicts, managed-file removal, executable/mode behavior, and recovery to an earlier manifest/generation.
4. Verify system-module activation semantics separately from standalone CLI behavior; standalone success does not prove nix-darwin activation/rollback integration. Hjem's Darwin support is currently labeled experimental. Document the actual recovery command/path for our pinned integration.
5. Keep clobber disabled by default. No reliance on undocumented mutable-file or recursive-merge semantics.

Gate: safe file lifecycle verified, identity mapping correct, Darwin integration understood, recoverable migration demonstrated on fixtures.

## Phase 4 — Unify static app files under Hjem

Migrate in small groups with the ownership ledger updated each time:

1. Shared static configs from chezmoi and HM, e.g. Yazi and eligible terminal/app files.
2. macOS-only files (including eligible Library content), preserving the current exclusions and documenting any manual app import such as Rectangle.
3. Linux desktop files currently under `users/maxpw/`: Hyprland Lua, Waybar JSON/CSS/scripts, swaync, wlogout, Ghostty, gammastep, and appropriate generated session config.

For each group:

- Preserve source contents, permissions/executable bits, host-specific generation and external command dependencies.
- Remove the old owner's exact declaration only as part of a controlled transfer. Do not leave parent-directory links overlapping child files, especially Hyprland's generated host.lua/hypridle.conf and HM/theme-generated files.
- Audit references to `/home/maxpw/nix-config`, `$HOME/nix-config`, relative includes, script paths and generated icon/package paths. Replace accidental checkout dependencies with deployed paths or packaged executables where appropriate.
- Keep program-generated HM files (including theme integrations) with HM unless intentionally migrating their generation too. Inventory all writers, not just literal xdg.configFile entries.
- Distinguish executable scripts from content: follow the repo policy that Nix/HM owns executables; package scripts and update callers where necessary rather than moving their ownership accidentally.
- Preserve `isLinuxDesktop` gating, not merely `isLinux`. Current headless/WSL hosts must not receive desktop config.
- Test Linux desktop declarations through an isolated evaluation fixture with that capability enabled; do not edit production host flags. Arrange a disposable graphical session or explicitly approved desktop host for interaction tests. Without one, desktop runtime parity remains a rollout blocker for that profile, not a claim of completion.
- Use immutable deployed files by default; application-written state stays outside linked trees. Any future writable seeding needs a specific ownership/recovery design, not a generic force=true workaround.

Gate per group: manifest/destination inspection, collision/removal tests, relevant app checks, and no dual ownership. Live transfer requires explicit host-specific approval.

## Phase 5 — Retire chezmoi and update recovery

After all intended hosts have migrated and no deployment still relies on chezmoi:

- Remove its package, `scripts/chezmoi.sh`, Makefile targets, shell aliases and obsolete bootstrap steps. Search the full repo for callers/tests/documentation before removal.
- Update README, BOOTSTRAP guidance, `docs/config-ownership-and-recovery.md`, and applicable AGENTS guidance with the accepted ownership map and edit/build/apply/recover workflows.
- Keep pi-config and unmanaged employer/credential locations out of scope.
- Verify clean disposable-home deployment has all expected files and excludes all protected paths. Re-test a config update, a deletion, and recovery.
- Archive the old source/history only with explicit authorization; do not delete the chezmoi repository or caches as incidental cleanup.

Gate: no active chezmoi dependencies, per-host rollout ledger complete, clear recovery and editing docs, no missing/misowned destinations.

## Verification and delivery boundaries

Implement in reviewable local changes: baseline/inventory; standalone Nixvim; parity and integration; Hjem fixture coverage; shared/Darwin files; Linux desktop files; retirement/docs. Do not combine tool adoption with plugin feature redesign or broad version upgrades where avoidable.

For Nix changes: targeted Alejandra, `make lint`, `nix flake check --no-build`, and `make check-linux` for relevant regression/flake changes. Build and execute the actual targeted editor/linker tests on their target systems; Linux evaluation on Darwin is not Linux execution. Use trusted remote builders only under the repository's remote workflow. For shell changes run `make check-scripts`. For this plan alone use `git diff --check`.

A Nix generation rollback alone may not restore files removed during cross-tool ownership transfer. Record how to deactivate the new owner, restore the old declaration/source revision and backed-up targets, and prevent both tools from applying concurrently. Exercise recovery on disposable fixtures first. Never promise app-data rollback from configuration generations.

No push, deployment, real-host switch/rebuild, destructive cleanup, secret relocation, stateVersion changes, or Determinate daemon ownership changes are authorized by this plan. Existing unrelated working-tree edits must remain untouched.

## Review amendments — Astra

Astra found no architectural blocker and considers inventory/candidate work ready to begin once implementation is authorized, but not live ownership transfer. Its upstream observations concern current main and must be rechecked against selected pins.

- **Exact deployed editor parity (Phases 1–2):** explicitly select Nixvim `wrapRc` and runtime-path policy, test the final HM-derived package/config in disposable XDG locations as well as the standalone candidate, and assert equivalent configuration, plugin revisions and native libraries. Remove the old `programs.neovim` enablement and `nvim/init.lua` force-disable at cutover. Standalone success alone is insufficient.
- **One editor package policy (Phase 1):** define Nixvim/nixpkgs revisions, package-set construction, unfree policy and native overrides once for both integration modes. Do not assume HM `useGlobalPkgs` or system `allowUnfree` controls Nixvim's separate package set. Execute native plugins on both target architectures.
- **Darwin side effects and completion (Phase 3):** inspect Hjem's application-link launch agent and ownership of `~/Applications/Nix User Apps`, not only dotfile declarations. Resolve any HM/nix-darwin overlap. Verify actual launch-agent completion and deployed provenance, including logged-out/headless behavior; a successful switch is not proof of successful linking. Current upstream activation can suppress a launch kick failure.
- **Cross-owner activation fixture (Phases 3–4):** exercise HM → Hjem → HM through both actual activation mechanisms in a disposable environment, with an injected failure between unlinking and linking and stale manifests present. Use a two-stage handoff unless tested explicit ordering establishes safety; Hjem's systemd/launchd lifecycle does not automatically share HM's activation ordering.
- **Editable-source navigation (Phases 0–2):** test find-config → edit source → build → run candidate → authorized deploy. Retarget `<leader>fc` or provide a clear source action rather than opening generated read-only `stdpath("config")` as the editable source. Document the Hyprland edit/build/apply/reload loop separately.
- **Desktop generated-file assertion (Phase 4):** compare generated destination manifests with `linuxDesktop = true`, including Stylix Ghostty and Waybar targets. Assert no competing owners even though production hosts currently hide those declarations.

## Review amendments — Fable and author synthesis

Fable also accepts the architecture, but identified decisions and additional coverage needed before candidate acceptance. Reviewer descriptions of Nixvim package-set defaults differ; resolve this from the selected pin and evaluated outputs rather than treating either description as authoritative for all versions.

### Implementation decisions and proposed defaults

- **Editor package set:** prefer a pinned Nixvim main and its compatible package set to avoid an incidental downgrade from today's unstable editor. Prove the selected HM integration can use that same package policy before committing to it. If it cannot, compare supported integration alternatives and the matching stable branch; do not silently downgrade plugins or change the whole system's package set. This is an implementation investigation, not a reason to ask the user to choose API internals.
- **VS Code mode:** prefer two explicit packages sharing common modules: terminal and reduced VS Code. Configure the VS Code Neovim extension to launch the reduced executable; do not attempt to inspect `vim.g.vscode` from a shell wrapper before Neovim starts. Assert terminal plugin runtime files and conflicting mappings are absent from the reduced package. A single-package conditional-loading alternative is acceptable only after proving equivalent isolation.
- **Supermaven autocomplete — user decision: preserve.** Keep Supermaven's inline AI suggestions, contextual Tab acceptance through Blink, and Ctrl+L direct acceptance. Nix manages the plugin. Prefer supported reproducible packaging for its autocomplete engine if practical, but a narrow runtime-download exception is approved when needed; keep downloaded engine/cache/state in writable application-data paths, never the config tree or Nix store. Do not disable or replace Supermaven as incidental migration cleanup. Document that the engine is not necessarily Nix-built and the service is not offline-capable. Offline core tests disable the integration only for that test; separate online tests verify suggestions and keybinding behavior without exposing credentials. This exception does not authorize unrelated runtime installers. Audit other AI integrations independently.
- **Desktop editing contract:** target immutable Hjem deployment and an explicit edit/build/apply/reload workflow. Do not retain checkout-backed links by accident. Verify wallpaper and include paths. A requested development override must be explicit and separate from deployment; desktop cutover waits for that workflow to be accepted.
- **Stylix:** Fable reports the Ghostty/Waybar targets currently generate no files because their HM program modules are disabled. Verify this in the desktop fixture. Preserve current hand-authored output under Hjem and explicitly disable conflicting dormant targets by default; do not enable new theming as part of migration. Keep other useful Stylix functionality and remove its import only if proven unused. If generated theming is desired later, choose one generator/owner for each resulting file.

### Required coverage and inventory additions

- Test the actual pinned Hjem NixOS activation mechanism on headless Linux and WSL, including switch without an interactive session, subsequent login, reboot, and failure/retry. Determine whether units are system or user scoped and whether lingering is needed; the reviewer explicitly marked user-unit behavior as an assumption. Do not change production session policy merely to make tests pass.
- Inventory `users/maxpw/agents`, `agent-tools.nix`, and Fleet/cliproxyapi `home.file` output. Preserve existing user edits. Hand-authored immutable files are Hjem candidates; intentionally mutable agent configuration remains a named HM exception until its writer contract is resolved. Pi resources stay under pi-config.
- Include `.config/jj` and `.config/mise` parent-directory management in the ledger. A shared real parent directory is not automatically a file collision; distinguish ordinary directory creation from exclusive directory links, cleanup behavior and actual competing child writers.
- Package `herdr-shell`, `lazygit-nvim-edit` and Waybar scripts with Nix as appropriate, preserve executable behavior, and update hardcoded callers such as Snacks. Do not lose these when retiring chezmoi.
- Plan pinned `extraPlugins` derivations for `ts-error-translator` and `twoslash-queries` if still absent from selected nixpkgs. Verify names and versions at implementation time.
- Assert candidate and final runtimepath do not discover the old deployed `lua/` or `lsp/` tree. During approved cutover, move the old tree into the designated recovery location, outside runtimepath; retaining it in place is not a safe backup.
- Record whether each host actually has chezmoi initialized. Use explicit per-host migration state in chezmoi template data or verified hostname-based ignore rules for staggered cutover; validate migrated and unmigrated rendered targets before applying. Source-repo changes must be coordinated, not inferred from Nix host names alone.
- Explicitly configure Joyce's Hjem directory from the account home and verify `system.primaryUser`. Keep Darwin application-link ownership/completion checks from Astra's review.
- Require Blink's Nix-built native backend with downloads disabled and missing-library failures visible. Replace Treesitter test-time parser installation with assertions that required JavaScript/TSX grammars are supplied and usable.

Phase 3's disposable Hjem experiments can run independently of the editor migration after inventory. Actual file transfers remain gated. Inventory/candidate experiments are ready to start once authorized; package compatibility, VS Code isolation, optional-agent policy, and activation semantics must be resolved before their respective acceptance gates.

## Review questions

1. Does the plan preserve the user's Nixvim + unified Hjem architecture without dismissing it solely for conversion cost?
2. Are editor isolation, startup ordering, native plugins, VS Code and behavioral tests sufficient to catch real regressions?
3. Are Hjem/HM boundaries, generated theme files, directory collisions and multi-host chezmoi retirement safe?
4. Are Darwin maturity, currently dormant Linux desktop config, writable state and rollback treated honestly?
5. What concrete blockers or missing decisions must be resolved before implementation/activation?

## References

- https://github.com/nix-community/nixvim
- https://nix-community.github.io/nixvim/user-guide/install.html
- https://github.com/feel-co/hjem
- https://hjem.feel-co.org/
- Local paths listed in the verified starting points above.
