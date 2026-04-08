{
  inputs,
  pkgs,
  lib,
  ...
}: let
  settings = import ./settings.nix {inherit pkgs;};
in {
  fonts.packages = with pkgs; [
    pkgs."nerd-fonts".fira-code
    pkgs."nerd-fonts".jetbrains-mono
  ];
  homebrew = {
    enable = true;

    brews = [
      "zsh"
      "jsonlint"
      "gnupg"
      "pinentry-mac"
    ];

    casks = [
      "colemak-dh"
      "1password"
      "rectangle"
      "whatsapp"
      "raycast"
      "chatgpt"
      "discord"
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
      "mullvad-vpn"
      "termius"
      "obsidian"
      "tidal"
      "monero-wallet"
      "cursor"
      "cmux"
      "t3-code"
      "linear-linear"
      "wispr-flow"
    ];

    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
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
    shell = settings.defaultShell;
  };

  programs.fish.enable = true;
  environment.shells = [pkgs.nushell];

  # Obsidian CLI (installed via Homebrew cask)
  environment.systemPath = [
    "/Applications/Obsidian.app/Contents/MacOS"
  ];

  # Required for some settings like homebrew to know what user to apply to.
  system.primaryUser = "max-vev";
}
