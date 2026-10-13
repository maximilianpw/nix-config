# T3 Code packaging, updates, and Homebrew handover

This repository packages the official nightly release artifacts in
`packages/t3code.nix`. `packages/t3code-release.json` pins one version and both
artifact hashes: the arm64 macOS ZIP and x86-64 Linux AppImage. No external
packaging flake or Homebrew tap is involved.

- Joyce installs the signed, unmodified app bundle through Nix. Hjem exposes it
  at `~/Applications/Nix User Apps/T3 Code (Nightly).app`.
- Kim's user service runs the bundled server via `t3` using Electron's Node
  runtime, not `npx`. Native modules ship with the release; startup does not
  fetch packages from npm. This includes an Electron runtime in the Linux
  closure even though Kim runs headlessly.
- Cuno does not run a T3 server.
- The backup manifest records the packaged server version.

## Updating

Run `make update` as usual. It updates core flake inputs, discovers T3 releases,
then updates Neovim plugin pins. `make update-all` also runs T3 discovery.
Plain `nix flake update` does **not** update this repo-local release manifest.

Discovery requires Python 3, Nix, and an authenticated `gh` CLI (`nix develop`
provides the tools, not authentication). The updater reads up to ten pages of
100 GitHub releases, orders nightly versions numerically, skips drafts and
incomplete uploads, and never downgrades. Both artifacts must be uploaded and
nonempty. It downloads them through `nix store prefetch-file` and compares any
upstream SHA-256 digest supplied by GitHub. Only after both downloads succeed
is the manifest replaced. Hashes pin bytes; they do not independently establish
publisher identity. The macOS package check verifies its code signature.

No newer complete release is a successful no-op. API/download failures fail the
command and preserve the T3 pin. Other steps of `make update` may already have
changed their own files; the whole Make target is not a transaction.

Review the manifest diff, then validate:

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
covers CLI/version/signature and the separate command above covers HTTP startup.

Rebuild Joyce and Kim explicitly from the same reviewed revision. These are full
system activations, not T3-only updates; other pending system changes also apply.
Close T3 before replacing its desktop version. Restarting Kim's service disrupts
connections, so deploy from an independent terminal rather than through T3.
Neither discovery nor package builds activate machines.

The `t3code` wrapper sets `T3CODE_DISABLE_AUTO_UPDATE=1`. Darwin also sets it in
the user launchd environment for Finder/Dock launches, which bypass the wrapper.
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
   nix build .#t3code --out-link /tmp/t3code-nix
   /tmp/t3code-nix/bin/t3 serve --help
   ```

2. Quit the existing app. Verify the new app with disposable state before using
   real data, using its wrapper (which disables updates):

   ```sh
   T3CODE_HOME="$(mktemp -d)" /tmp/t3code-nix/bin/t3code
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
