{
  lib,
  stdenv,
  stdenvNoCC,
  bun,
  cacert,
  makeWrapper,
  node-gyp,
  nodejs,
  python3,
}: let
  src = ./homelab-mcp/source.tar.gz;
  dependencies = stdenvNoCC.mkDerivation {
    pname = "homelab-mcp-dependencies";
    version = "2026-10-16";
    inherit src;
    sourceRoot = ".";
    nativeBuildInputs = [bun cacert];
    dontConfigure = true;
    dontBuild = true;
    # Patching shebangs would make this fixed-output path reference the store.
    dontFixup = true;
    installPhase = ''
      export HOME="$TMPDIR/home"
      export BUN_INSTALL_CACHE_DIR="$TMPDIR/bun-cache"
      bun install --frozen-lockfile --production --ignore-scripts
      mkdir -p "$out"
      cp -r node_modules "$out/"
    '';
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-pPPW230hlOOIwmoCwZ2FYoDSGMJkjtaiz49i9RDzCds=";
  };
in
  stdenv.mkDerivation {
    pname = "homelab-mcp";
    version = "0-unstable-2026-10-16-actual-fix";
    inherit src;
    sourceRoot = ".";
    nativeBuildInputs = [makeWrapper node-gyp nodejs python3];
    dontConfigure = true;
    # The bun patch in source.tar.gz makes better-sqlite3 loadable by Bun; the
    # bundled prebuilds are unpatched, so the addon is compiled here instead.
    buildPhase = ''
      runHook preBuild
      cp -r ${dependencies}/node_modules node_modules
      chmod -R u+w node_modules
      pushd node_modules/better-sqlite3
      rm -rf prebuilds
      node-gyp rebuild --release --force_build=1 --nodedir=${nodejs}
      find build -mindepth 1 -not -path build/Release -not -path build/Release/better_sqlite3_bun.node -delete
      popd
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/homelab-mcp" "$out/bin"
      cp -r src drizzle package.json node_modules "$out/lib/homelab-mcp/"
      makeWrapper ${lib.getExe bun} "$out/bin/homelab-mcp" \
        --add-flags "$out/lib/homelab-mcp/src/main.ts"
      makeWrapper ${lib.getExe bun} "$out/bin/homelab-mcp-admin" \
        --add-flags "$out/lib/homelab-mcp/src/cli.ts"
      runHook postInstall
    '';
    meta = {
      description = "Authenticated MCP for Kim's media stack and Actual Budget";
      mainProgram = "homelab-mcp";
      platforms = ["x86_64-linux"];
    };
  }
