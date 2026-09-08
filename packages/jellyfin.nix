# Based on nixpkgs pkgs/by-name/je/jellyfin/package.nix.
{
  lib,
  fetchFromGitHub,
  nixosTests,
  dotnetCorePackages,
  buildDotnetModule,
  jellyfin-ffmpeg,
  fontconfig,
  freetype,
  jellyfin-web,
  sqlite,
  versionCheckHook,
}:
buildDotnetModule (finalAttrs: {
  pname = "jellyfin";
  version = "12.0.0"; # Keep jellyfin-web on the matching release.

  src = fetchFromGitHub {
    owner = "jellyfin";
    repo = "jellyfin";
    # Upstream's tag omits the patch version; the assembly version is 12.0.0.
    tag = "v12.0";
    hash = "sha256-z40crHV4vH27vDQBFcM58tQ5JW8wtIW3w981Rpp5h1E=";
  };

  propagatedBuildInputs = [sqlite];

  projectFile = "Jellyfin.Server/Jellyfin.Server.csproj";
  executables = ["jellyfin"];
  nugetDeps = ./jellyfin/nuget-deps.json;
  runtimeDeps = [
    jellyfin-ffmpeg
    fontconfig
    freetype
  ];
  dotnet-sdk = dotnetCorePackages.sdk_10_0;
  dotnet-runtime = dotnetCorePackages.aspnetcore_10_0;
  dotnetBuildFlags = ["--no-self-contained"];

  makeWrapperArgs = [
    "--add-flags"
    "--ffmpeg=${jellyfin-ffmpeg}/bin/ffmpeg"
    "--add-flags"
    "--webdir=${jellyfin-web}/share/jellyfin-web"
  ];

  nativeInstallCheckInputs = [versionCheckHook];
  doInstallCheck = true;
  # --version rejects the wrapper's extra flags; --help prints the version too.
  versionCheckProgramArg = "--help";

  passthru.tests.smoke-test = nixosTests.jellyfin;

  meta = {
    description = "Free Software Media System";
    homepage = "https://jellyfin.org/";
    changelog = "https://github.com/jellyfin/jellyfin/releases/tag/v12.0";
    license = lib.licenses.gpl2Plus;
    mainProgram = "jellyfin";
    platforms = finalAttrs.dotnet-runtime.meta.platforms;
  };
})
