# `workspaces`: JJ and Git workspaces in one picker, opened as Rex sessions.
# Rex's workspace actions (users/maxpw/files/managed/.config/rex/projects.lua)
# run it; it calls `rex` back to open checkouts and list terminals.
# Regenerate bun.nix with `bunx bun2nix -o bun.nix` after changing bun.lock.
{
  lib,
  stdenvNoCC,
  bun,
  bun2nix,
  makeWrapper,
  git,
  jujutsu,
  lsof,
}:
assert lib.assertMsg (lib.versionAtLeast jujutsu.version "0.46") "workspaces requires JJ >= 0.46 for colocated workspaces";
assert lib.assertMsg (lib.versionAtLeast bun.version "1.3.14") "workspaces requires Bun >= 1.3.14";
  stdenvNoCC.mkDerivation {
    pname = "workspaces";
    inherit (lib.importJSON ./package.json) version;
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [./src ./package.json ./bun.lock];
    };

    nativeBuildInputs = [bun bun2nix.hook makeWrapper];
    bunDeps = bun2nix.fetchBunDeps {bunNix = ./bun.nix;};
    bunInstallFlags =
      ["--frozen-lockfile" "--production" "--linker=hoisted"]
      ++ lib.optionals stdenvNoCC.hostPlatform.isDarwin ["--backend=copyfile"];
    dontRunLifecycleScripts = true;
    dontUseBunPatch = true;
    dontUseBunBuild = true;
    dontUseBunCheck = true;
    dontUseBunInstall = true;
    # Bun embeds its executable payload and signature. Generic binary fixups
    # invalidate these; the wrapper already uses absolute store references.
    dontFixup = true;

    buildPhase = ''
      runHook preBuild
      bun build src/cli.ts --compile --outfile dist/workspaces
      runHook postBuild
    '';

    # `rex` stays on the caller's PATH: it must match the running server.
    installPhase = ''
      runHook preInstall
      install -Dm755 dist/workspaces "$out/libexec/workspaces"
      makeWrapper "$out/libexec/workspaces" "$out/bin/workspaces" \
        --prefix PATH : ${lib.makeBinPath [jujutsu git lsof]}
      runHook postInstall
    '';

    meta = {
      description = "JJ and Git workspaces in one picker, opened as Rex sessions";
      mainProgram = "workspaces";
      platforms = ["aarch64-darwin" "aarch64-linux" "x86_64-linux"];
    };
  }
