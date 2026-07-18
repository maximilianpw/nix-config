{
  currentSystemUser,
  pkgs,
  ...
}: let
  settings = import ./settings.nix {inherit pkgs;};
  inherit (settings) cliProxy;
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
      "ollama"
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
      "t3-code"
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
  # macOS system preferences (imported from current defaults)
  system.defaults = {
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

  # Required for some settings like homebrew to know what user to apply to.
  system.primaryUser = "max-vev";
}
