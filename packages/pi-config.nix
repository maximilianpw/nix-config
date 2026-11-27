# The pi-config checkout with its production dependencies installed, for
# hosts that have not cloned ~/pi-config.
{
  bun,
  lib,
  runCommand,
  src,
  stdenv,
  stdenvNoCC,
  bunOs ?
    if stdenv.hostPlatform.isDarwin
    then "darwin"
    else "linux",
  bunCpu ?
    if stdenv.hostPlatform.isAarch64
    then "arm64"
    else "x64",
}: let
  platform = "${bunOs}-${bunCpu}";

  # Bump after a bun.lock or recipe change: the build fails with the new hash.
  hashes = {
    linux-x64 = "sha256-lNvD8GxzAh3Z7akJ5NK/JH1WeXccqB3X3AEE/YETtEs=";
    darwin-arm64 = "sha256-lNvD8GxzAh3Z7akJ5NK/JH1WeXccqB3X3AEE/YETtEs=";
  };

  buildPhase = ''
    runHook preBuild

    export HOME=$TMPDIR BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache
    # Bun trusts only its bundled roots, so a TLS-inspecting proxy (Aikido on
    # joyce) fails with SELF_SIGNED_CERT_IN_CHAIN. Trust the bundle Nix uses
    # for its own downloads: Determinate builds it from the macOS keychain,
    # and Linux sandboxes bind-mount Nix's ssl-cert-file at the second path.
    for ca in /etc/nix/macos-keychain.crt /etc/ssl/certs/ca-certificates.crt; do
      if [ -r "$ca" ]; then
        export NODE_EXTRA_CA_CERTS=$ca
        break
      fi
    done
    cp "$src"/package.json "$src"/bun.lock .
    for manifest in "$src"/extensions/*/package.json; do
      workspace=extensions/$(basename "$(dirname "$manifest")")
      mkdir -p "$workspace"
      cp "$manifest" "$workspace/"
    done
    bun install --frozen-lockfile --production --ignore-scripts --no-progress \
      --os=${bunOs} --cpu=${bunCpu}
    # Bun cannot select by libc and installs musl builds as well; Nix's
    # Linux is glibc, and the musl Claude Agent SDK binary alone is 258 MB.
    ${lib.optionalString (bunOs == "linux") "rm -rf node_modules/.bun/*-musl@*"}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    find . -name node_modules -prune -exec cp -a --parents {} $out \;

    runHook postInstall
  '';

  # A fixed-output derivation is reused whenever its name and hash match, so
  # the name changes with the lockfile and the recipe: a stale hash then fails
  # the build instead of silently keeping old dependencies.
  inputId = builtins.substring 0 16 (builtins.hashString "sha256" (
    builtins.readFile "${src}/bun.lock" + buildPhase + installPhase
  ));

  nodeModules = stdenvNoCC.mkDerivation {
    name = "pi-config-node-modules-${platform}-${inputId}";
    inherit src buildPhase installPhase;
    nativeBuildInputs = [bun];
    dontUnpack = true;
    dontFixup = true;

    outputHashMode = "recursive";
    outputHash = hashes.${platform} or (throw "pi-config: no dependency hash for ${platform}");
  };
in
  runCommand "pi-config" {passthru = {inherit nodeModules;};} ''
    cp -r ${src} $out
    chmod -R u+w $out
    cp -a ${nodeModules}/. $out/
  ''
