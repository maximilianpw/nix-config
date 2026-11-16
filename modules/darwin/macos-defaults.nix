_: {
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
}
