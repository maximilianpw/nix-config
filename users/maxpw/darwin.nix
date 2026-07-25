{
  currentSystemUser,
  pkgs,
  lib,
  ...
}: let
  settings = import ./settings.nix {inherit pkgs;};
  inherit (settings) cliProxy t3codeRelease;
  t3codeTapName = "maxpw/t3code-nightly";
  t3codeCaskToken = "maxpw-t3-code-nightly";
  t3codeCaskFullName = "${t3codeTapName}/${t3codeCaskToken}";
  t3codeNightlyCask = pkgs.writeText "${t3codeCaskToken}.rb" ''
    cask "${t3codeCaskToken}" do
      version "${t3codeRelease.version}"
      sha256 "${t3codeRelease.darwinArm64Sha256}"

      url "https://github.com/pingdotgg/t3code/releases/download/v#{version}/T3-Code-#{version}-arm64.dmg",
          verified: "github.com/pingdotgg/t3code/"
      name "T3 Code Nightly"
      desc "Minimal GUI for AI code agents"
      homepage "https://t3.codes/"

      depends_on macos: :monterey

      app "T3 Code (Nightly).app"

      zap trash: [
        "~/.t3/userdata",
        "~/Library/Application Support/T3 Code (Alpha)",
        "~/Library/Application Support/t3code",
        "~/Library/Caches/com.t3tools.t3code",
        "~/Library/HTTPStorages/com.t3tools.t3code",
        "~/Library/Preferences/com.t3tools.t3code.plist",
        "~/Library/Saved Application State/com.t3tools.t3code.savedState",
      ]
    end
  '';
  t3codeHomebrewTap =
    pkgs.runCommand "homebrew-t3code-nightly-${t3codeRelease.version}" {
      nativeBuildInputs = [pkgs.git];
    } ''
      mkdir -p "$out/Casks"
      cp ${t3codeNightlyCask} "$out/Casks/${t3codeCaskToken}.rb"

      git -C "$out" init --quiet --initial-branch=main
      git -C "$out" add "Casks/${t3codeCaskToken}.rb"
      GIT_AUTHOR_NAME="nix-config" \
        GIT_AUTHOR_EMAIL="nix-config@localhost" \
        GIT_AUTHOR_DATE="2000-01-01T00:00:00Z" \
        GIT_COMMITTER_NAME="nix-config" \
        GIT_COMMITTER_EMAIL="nix-config@localhost" \
        GIT_COMMITTER_DATE="2000-01-01T00:00:00Z" \
        git -C "$out" -c commit.gpgSign=false commit --quiet \
          --message="Pin T3 Code ${t3codeRelease.version}"
    '';
in {
  imports = [
    ../../modules/core/shells.nix
    ../../modules/fleet/ssh-access.nix
  ];

  # Homebrew owns the CLIProxyAPI binary; nix-darwin owns its configuration
  # and LaunchAgent so the service never falls back to Homebrew's sample keys.
  environment.etc."cliproxyapi.conf".text = ''
    host: "${cliProxy.host}"
    port: ${toString cliProxy.port}
    auth-dir: "/Users/${currentSystemUser}/.cli-proxy-api"

    api-keys:
      - "${cliProxy.apiKey}"

    remote-management:
      allow-remote: false
      secret-key: ""

    usage-statistics-enabled: false
  '';

  launchd.user.agents.cliproxyapi.serviceConfig = {
    ProgramArguments = [
      "/opt/homebrew/opt/cliproxyapi/bin/cliproxyapi"
      "-config"
      "/etc/cliproxyapi.conf"
    ];
    RunAtLoad = true;
    KeepAlive = true;
    ProcessType = "Background";
    ThrottleInterval = 5;
    StandardOutPath = "/Users/${currentSystemUser}/Library/Logs/cliproxyapi.log";
    StandardErrorPath = "/Users/${currentSystemUser}/Library/Logs/cliproxyapi.log";
  };

  # Fonts come from Home Manager (users/maxpw/modules/fonts.nix), which
  # installs them to ~/Library/Fonts/HomeManager on macOS.
  homebrew = {
    enable = true;

    taps = [
      {
        name = t3codeTapName;
        clone_target = "file://${t3codeHomebrewTap}";
        trusted = true;
      }
    ];

    brews = [
      "cliproxyapi"
      "ffmpeg"
      "gnupg"
      "jsonlint"
      "pinentry-mac"
      "zsh"
    ];

    casks = [
      "colemak-dh"
      "1password"
      "rectangle"
      "whatsapp"
      "chatgpt"
      "legcord"
      "notion"
      "slack"
      "proton-mail"
      "ghostty"
      "aws-vpn-client"
      "orbstack"
      "claude"
      "helium-browser"
      "yaak"
      "zed"
      "studio-3t-community"
      "cursor"
      "mullvad-vpn"
      "termius"
      "obsidian"
      "tidal"
      "cmux"
      {
        name = t3codeCaskFullName;
        greedy = false;
        trusted = true;
      }
      "linear"
      "wispr-flow"
      "freelens"
      "nextcloud"
    ];

    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
      # Homebrew now requires an explicit confirmation flag when `brew bundle`
      # is run with cleanup during nix-darwin activation.
      extraFlags = ["--force-cleanup"];
    };
  };

  # Homebrew requires private casks to come from a tap. The pre-activation
  # migration removes conflicting or mismatched installs; Homebrew Bundle then
  # clones the exact Nix-built tap and installs its pinned cask.
  system = {
    activationScripts = {
      preActivation.text = lib.mkAfter ''
        if [ -x /opt/homebrew/bin/brew ]; then
          run_t3code_brew() {
            sudo \
              --user=${lib.escapeShellArg currentSystemUser} \
              --set-home \
              -- /opt/homebrew/bin/brew "$@"
          }

          # Migrate from official stable/nightly casks without zapping shared
          # T3 Code state.
          for old_cask in t3-code t3-code@nightly; do
            if run_t3code_brew list --cask "$old_cask" >/dev/null 2>&1; then
              run_t3code_brew unpin --cask "$old_cask" >/dev/null 2>&1 || true
              run_t3code_brew uninstall --cask "$old_cask"
            fi
          done

          installed_t3code="$(
            run_t3code_brew list --cask --versions ${lib.escapeShellArg t3codeCaskToken} \
              2>/dev/null || true
          )"
          installed_t3code_version="''${installed_t3code#* }"
          installed_t3code_app_version="$(
            /usr/libexec/PlistBuddy \
              -c "Print :CFBundleShortVersionString" \
              "/Applications/T3 Code (Nightly).app/Contents/Info.plist" \
              2>/dev/null || true
          )"

          if [ "$installed_t3code_version" != "${t3codeRelease.version}" ] ||
            [ "$installed_t3code_app_version" != "${t3codeRelease.version}" ]; then
            if [ -n "$installed_t3code" ]; then
              run_t3code_brew unpin --cask ${lib.escapeShellArg t3codeCaskToken} \
                >/dev/null 2>&1 || true
              run_t3code_brew uninstall --cask ${lib.escapeShellArg t3codeCaskToken}
            fi

            # Force Homebrew Bundle to clone the tap generated by this revision.
            run_t3code_brew untap --force ${lib.escapeShellArg t3codeTapName} \
              >/dev/null 2>&1 || true
          fi
        fi
      '';

      postActivation.text = lib.mkAfter ''
        if [ -x /opt/homebrew/bin/brew ]; then
          run_t3code_brew() {
            sudo \
              --user=${lib.escapeShellArg currentSystemUser} \
              --set-home \
              -- /opt/homebrew/bin/brew "$@"
          }

          installed_t3code="$(
            run_t3code_brew list --cask --versions ${lib.escapeShellArg t3codeCaskToken} \
              2>/dev/null || true
          )"
          installed_t3code_version="''${installed_t3code#* }"
          installed_t3code_app_version="$(
            /usr/libexec/PlistBuddy \
              -c "Print :CFBundleShortVersionString" \
              "/Applications/T3 Code (Nightly).app/Contents/Info.plist" \
              2>/dev/null || true
          )"

          if [ "$installed_t3code_version" != "${t3codeRelease.version}" ] ||
            [ "$installed_t3code_app_version" != "${t3codeRelease.version}" ]; then
            echo "error: T3 Code ${t3codeRelease.version} was not installed from ${t3codeTapName}" >&2
            exit 1
          fi

          if ! run_t3code_brew list --cask --pinned |
            /usr/bin/grep -Fxq ${lib.escapeShellArg t3codeCaskToken}; then
            run_t3code_brew pin --cask ${lib.escapeShellArg t3codeCaskToken}
          fi
        fi
      '';
    };

    # macOS system preferences (imported from current defaults)
    defaults = {
      dock = {
        autohide = true;
        tilesize = 47;
        show-recents = false;
        minimize-to-application = true;
        mineffect = "scale";
        expose-group-apps = true;
        mru-spaces = false; # don't rearrange Spaces based on most recent use
      };

      finder = {
        AppleShowAllExtensions = true;
        FXPreferredViewStyle = "icnv"; # icon view
        FXEnableExtensionChangeWarning = false;
        ShowPathbar = true;
        ShowStatusBar = true;
        _FXSortFoldersFirst = true;
      };

      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";
        AppleShowAllExtensions = true;
        ApplePressAndHoldEnabled = false; # key repeat instead of accent menu
        AppleEnableSwipeNavigateWithScrolls = false;
        "com.apple.swipescrolldirection" = false; # non-natural scroll
        # Keyboard: fast repeat
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
        # Disable auto-correct annoyances
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        # Expanded save/print dialogs by default
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        # Don't save to iCloud by default
        NSDocumentSaveNewDocumentsToCloud = false;
      };

      screencapture = {
        target = "preview";
        show-thumbnail = true;
      };

      CustomUserPreferences = {
        "com.apple.finder" = {
          CreateDesktop = false; # no desktop icons
        };
        NSGlobalDomain = {
          AppleMiniaturizeOnDoubleClick = false;
        };
      };
    };

    # Required for some settings like homebrew to know what user to apply to.
    primaryUser = "max-vev";
  };

  # The user should already exist, but we need to set this up so Nix knows
  # what our home directory is (https://github.com/LnL7/nix-darwin/issues/423).
  # macOS primary login user. We keep configs in users/maxpw but the on-system
  # account remains max-vev. This indirection is handled via userDir in mksystem.nix.
  users.users.max-vev = {
    home = "/Users/max-vev";
    shell = settings.loginShell;
  };

  # Obsidian CLI (installed via Homebrew cask)
  environment.systemPath = [
    "/Applications/Obsidian.app/Contents/MacOS"
  ];
}
