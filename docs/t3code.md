# T3 Code packaging, updates, and Homebrew handover

T3 Code uses the pinned `llm-agents` build recipe with a narrow nightly override
in `packages/t3code-nightly.nix`. `t3code` provides Kim's CLI/server and Joyce's
CLI; `t3code-desktop` uses the desktop output of that same build. The override
pins the source tag, pnpm dependency hash, and Rust dependency hash and adjusts
the build-time version and Nightly branding. There is no copied package recipe
or release-artifact updater. Remove the override when upstream offers nightlies.

- The current pin is **0.0.46-nightly.20261011.2994**, matching the release used
  by our former custom binary package—not the older upstream Alpha release.
- Joyce installs the source-built app through Nix. Hjem exposes it at
  `~/Applications/Nix User Apps/T3 Code (Nightly).app`. This is not the official
  signed/notarized nightly release bundle.
- Kim's user service runs `t3 serve` with packaged Node.js, not Electron or
  `npx`. Startup does not fetch packages from npm. The upstream wrapper adds
  its coding-agent providers to PATH.
- Cuno does not run a T3 server.
- The backup manifest still records the packaged server version. The service state
  path, loopback port, Tailscale exposure, and online backup are unchanged.

## Migrating from the custom nightly package

The version is unchanged, but packaging and the Electron runtime differ. Test
the source-built desktop with disposable state before opening existing data.
Preserve a restorable backup first; rolling back Nix does not undo database
migrations. Never run the old and new apps against the same state concurrently.
Re-add stale Dock shortcuts after activation and verify history, pairing, and
the connection to Kim before retiring the old generation.

## Updating

`make update` / `nix flake update llm-agents` update the upstream build recipe
and its dependencies. **They do not advance our nightly source pin.** Updating
that pin is a separate reviewed change in `packages/t3code-nightly.nix`:

1. Choose an explicit nightly tag and update `version`. Never downgrade casually.
2. Prefetch its source hash with
   `nix store prefetch-file --unpack --json https://github.com/pingdotgg/t3code/archive/refs/tags/v<VERSION>.tar.gz`.
3. Replace the pnpm and Cargo hashes with `lib.fakeHash`, build
   `nix build .#t3code.pnpmDeps --no-link` and
   `nix build .#t3code.resourceMonitor.cargoDeps --no-link`, and record the
   reported actual hashes. These expected hash-mismatch failures discover the
   hashes; rerun with real hashes and never commit placeholders.
4. Build and verify both platforms below. Nightlies may require compatibility
   fixes as upstream changes. A dependency-fetch success is not a package test.

Both packages share the override. Do not update only the outer wrapper version:
the built package manifests, native monitor, and dependency sources must agree.
The regression check enforces the nightly source/version relationship; the
package checks verify CLI and desktop manifest versions.

Review the pin and lockfile changes, then validate:

```sh
nix build .#checks.aarch64-darwin.t3code-package --no-link
# Disposable-state server smoke test outside macOS's build sandbox:
package=$(nix build .#t3code --no-link --print-out-paths)
version=$(nix eval --raw .#t3code.version)
python3 scripts/tests/t3code-server-smoke.py "$package/bin/t3" "$version"
# On a Linux builder:
nix build .#checks.x86_64-linux.t3code-package --no-link
make check-linux
```

The Linux package check includes the HTTP smoke test. On macOS, the Nix build
sandbox rejects native server subprocesses (`spawn EPERM`), so its build check
covers CLI/version and desktop bundle structure; the separate command above
covers HTTP startup. It does not assert notarization or a publisher signature.

Rebuild Joyce and Kim explicitly from the same reviewed revision. These are full
system activations, not T3-only updates; other pending system changes also apply.
Close T3 before replacing its desktop version. Restarting Kim's service disrupts
connections, so deploy from an independent terminal rather than through T3.
Neither lockfile updates nor package builds activate machines.

Darwin sets `T3CODE_DISABLE_AUTO_UPDATE=1` in the user launchd environment
for the Nix-owned desktop, including Finder/Dock launches.
After activation, verify `launchctl getenv T3CODE_DISABLE_AUTO_UPDATE` prints `1`
and relaunch the app. GUI behavior and connection to Kim require a manual smoke
test; CLI/package checks alone do not establish those.

## One-time migration from Homebrew

**Do not simply remove the cask and let `brew bundle cleanup` handle it.** This
repo uses cleanup `zap`, and the old cask's zap stanza deletes T3 userdata.
Darwin pre-activation refuses to proceed if any old T3 cask remains installed.
It only inspects Homebrew; it never uninstalls anything automatically. An
inspection failure also blocks activation.

1. Build the Nix package without activating:

   ```sh
   nix build .#t3code-desktop --out-link /tmp/t3code-desktop-nix
   nix run .#t3code -- serve --help
   ```

2. Quit the existing app. Verify the new app with disposable state before using
   real data, explicitly disabling updates:

   ```sh
   T3CODE_DISABLE_AUTO_UPDATE=1 T3CODE_HOME="$(mktemp -d)" /tmp/t3code-desktop-nix/bin/t3code-desktop
   ```

   Verify launch and updater behavior, then quit. Preserve/back up existing T3
   data before opening a newer release against it; database migrations may not
   be reversible by rolling back the Nix generation.

3. As the normal Mac user, inspect installed casks and explicitly remove only
   the installed T3 cask, **without `--zap`**. For the previously managed cask:

   ```sh
   brew list --cask -1
   brew trust --tap maxpw/t3code-nightly
   brew unpin --cask maxpw-t3-code-nightly
   brew uninstall --cask maxpw-t3-code-nightly
   brew untap maxpw/t3code-nightly
   ```

   If an official `t3-code` or `t3-code@nightly` cask is installed instead, use
   that token. Skip unpin if it is not pinned. Never use `--zap` or delete T3's
   Application Support/userdata directories.

4. Activate Joyce explicitly. Hjem will expose the Nix app; remove/re-add stale
   Dock shortcuts pointing to `/Applications`. Verify app version, disabled
   updater, existing history, and connection to Kim after its matching rebuild.

These migration commands are operator steps, not part of `make update`.
