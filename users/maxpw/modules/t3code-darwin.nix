{
  currentSystemUser,
  pkgs,
  lib,
  ...
}: let
  inherit (import ../settings.nix {inherit pkgs;}) t3codeRelease;
  t3codeTapName = "maxpw/t3code-nightly";
  t3codeCaskToken = "maxpw-t3-code-nightly";
  t3codeCaskFullName = "${t3codeTapName}/${t3codeCaskToken}";
  t3codeCaskMarkers = [
    "@T3CODE_CASK_TOKEN@"
    "@T3CODE_RELEASE_VERSION@"
    "@T3CODE_DARWIN_SHA256@"
  ];
  t3codeCaskText = let
    rendered =
      lib.replaceStrings
      t3codeCaskMarkers
      [t3codeCaskToken t3codeRelease.version t3codeRelease.darwinArm64Sha256]
      (builtins.readFile ../t3code-nightly.rb);
  in
    assert lib.assertMsg
    (lib.all (marker: !lib.hasInfix marker rendered) t3codeCaskMarkers)
    "users/maxpw/t3code-nightly.rb contains an unsubstituted template marker"; rendered;
  t3codeNightlyCask = pkgs.writeText "${t3codeCaskToken}.rb" t3codeCaskText;
  t3codeHomebrewTap =
    pkgs.runCommand "homebrew-t3code-nightly-${t3codeRelease.version}" {
      nativeBuildInputs = [pkgs.git];
    } ''
      export T3CODE_NIGHTLY_CASK=${lib.escapeShellArg (toString t3codeNightlyCask)}
      export T3CODE_CASK_TOKEN=${lib.escapeShellArg t3codeCaskToken}
      export T3CODE_RELEASE_VERSION=${lib.escapeShellArg t3codeRelease.version}
      ${builtins.readFile ../../../scripts/t3code-build-tap.sh}
    '';
in {
  homebrew = {
    taps = [
      {
        name = t3codeTapName;
        clone_target = "file://${t3codeHomebrewTap}";
        trusted = true;
      }
    ];

    casks = [
      {
        name = t3codeCaskFullName;
        greedy = false;
        trusted = true;
      }
    ];
  };

  # Homebrew requires private casks to come from a tap. The pre-activation
  # migration removes conflicting or mismatched installs; Homebrew Bundle then
  # clones the exact Nix-built tap and installs its pinned cask.
  system.activationScripts = {
    preActivation.text = lib.mkAfter ''
      export T3CODE_SYSTEM_USER=${lib.escapeShellArg currentSystemUser}
      export T3CODE_CASK_TOKEN=${lib.escapeShellArg t3codeCaskToken}
      export T3CODE_RELEASE_VERSION=${lib.escapeShellArg t3codeRelease.version}
      export T3CODE_TAP_NAME=${lib.escapeShellArg t3codeTapName}
      ${builtins.readFile ../../../scripts/t3code-pre-activation.sh}
    '';

    postActivation.text = lib.mkAfter ''
      export T3CODE_SYSTEM_USER=${lib.escapeShellArg currentSystemUser}
      export T3CODE_CASK_TOKEN=${lib.escapeShellArg t3codeCaskToken}
      export T3CODE_RELEASE_VERSION=${lib.escapeShellArg t3codeRelease.version}
      export T3CODE_TAP_NAME=${lib.escapeShellArg t3codeTapName}
      ${builtins.readFile ../../../scripts/t3code-post-activation.sh}
    '';
  };
}
