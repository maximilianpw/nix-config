{
  currentSystemUser,
  pkgs,
  lib,
  ...
}: let
  settings = import ./settings.nix {inherit pkgs;};
  inherit (settings) cliProxy t3codeRelease;
  t3codeNightlyCask = pkgs.writeText "t3-code@nightly.rb" ''
    cask "t3-code@nightly" do
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
in {
  imports = [
    ../../modules/core/shells.nix
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
        name = "t3-code@nightly";
        greedy = false;
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

  # Install the exact release shared with Kim before Homebrew Bundle runs.
  # Keeping the official token in homebrew.casks lets Bundle retain the
  # privately installed cask during cleanup.
  system = {
    activationScripts.preActivation.text = lib.mkAfter ''
      if [ -x /opt/homebrew/bin/brew ]; then
        run_t3code_brew() {
          sudo \
            --user=${lib.escapeShellArg currentSystemUser} \
            --set-home \
            -- /opt/homebrew/bin/brew "$@"
        }

        # Migrate from the stable cask without zapping shared T3 Code state.
        if run_t3code_brew list --cask t3-code >/dev/null 2>&1; then
          run_t3code_brew uninstall --cask t3-code
        fi

        installed_t3code="$(
          run_t3code_brew list --cask --versions t3-code@nightly 2>/dev/null || true
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
            run_t3code_brew unpin --cask t3-code@nightly >/dev/null 2>&1 || true
            run_t3code_brew uninstall --cask t3-code@nightly
          fi

          run_t3code_brew install --cask ${lib.escapeShellArg t3codeNightlyCask}
        fi

        if ! run_t3code_brew list --cask --pinned |
          /usr/bin/grep -Fxq "t3-code@nightly"; then
          run_t3code_brew pin --cask t3-code@nightly
        fi
      fi
    '';

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
