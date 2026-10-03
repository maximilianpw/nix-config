{
  lib,
  stdenvNoCC,
  bun,
  cacert,
  makeWrapper,
}: let
  src = ./homelab-mcp/source.tar.gz;
  dependencies = stdenvNoCC.mkDerivation {
    pname = "homelab-mcp-dependencies";
    version = "2026-10-01";
    inherit src;
    sourceRoot = ".";
    nativeBuildInputs = [bun cacert];
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      export HOME="$TMPDIR/home"
      export BUN_INSTALL_CACHE_DIR="$TMPDIR/bun-cache"
      bun install --frozen-lockfile --production --ignore-scripts
      mkdir -p "$out"
      cp -r node_modules "$out/"
    '';
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-rwo9RuKtIfOjbCzdKnFcNHTpClp65g6pEIYf7Y9of5E=";
  };
in
  stdenvNoCC.mkDerivation {
    pname = "homelab-mcp";
    version = "0-unstable-2026-10-03-music";
    inherit src;
    sourceRoot = ".";
    nativeBuildInputs = [makeWrapper];
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/homelab-mcp" "$out/bin"
      cp -r src drizzle package.json "$out/lib/homelab-mcp/"
      ln -s ${dependencies}/node_modules "$out/lib/homelab-mcp/node_modules"
      makeWrapper ${lib.getExe bun} "$out/bin/homelab-mcp" \
        --add-flags "$out/lib/homelab-mcp/src/main.ts"
      makeWrapper ${lib.getExe bun} "$out/bin/homelab-mcp-admin" \
        --add-flags "$out/lib/homelab-mcp/src/cli.ts"
      runHook postInstall
    '';
    meta = {
      description = "Authenticated MCP for Kim's media stack";
      mainProgram = "homelab-mcp";
      platforms = ["x86_64-linux"];
    };
  }
