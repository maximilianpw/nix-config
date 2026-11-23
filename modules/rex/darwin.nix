# Rex's init.lua covers only keys, actions and hosts; the app reads these at
# launch. Key names are preview internals (list them with
# `strings "/Applications/Rex Beta.app/Contents/MacOS/Rex" | grep '^Workspace\.'`)
# and a renamed key is silently ignored. darkThemeID is left to the app: it
# names an entry in the app-written Workspace.customThemes blob, which the
# import_catppuccin_mocha action in theme.lua fills.
_: {
  system.defaults.CustomUserPreferences."com.superlogical.rex" = {
    "Workspace.terminalFontName" = "Maple Mono NF";
    "Workspace.terminalFontPointSize" = 14.5;
    "Workspace.terminalOptionKeyBehavior" = "leftActsAsAlt";
    "Workspace.appearance" = "system";
    "Workspace.interfaceStyle" = "useTheme";
    "Workspace.lightThemeID" = "merino-light";
    "Workspace.tabStyle" = "vertical";
    "Workspace.tabIconTintMode" = "off";
    "Workspace.sidebarPosition" = "left";
    "Workspace.sidebarShowsActivity" = false;
    # A program that reports itself blocked, failed or done (OSC 7501; the
    # coding agents do) raises a macOS notification while Rex is in the
    # background, and counts on the Dock icon until its tab is seen.
    "Workspace.showsProgramActivityNotifications" = true;
    "Workspace.showsProgramActivityDockBadge" = true;
    "Workspace.paneDensity" = "compact";
    "Workspace.inactivePaneFadeMode" = "both";
    "Workspace.terminalPaddingColor" = "background";
    "Workspace.usesPaneGlass" = false;
    # Lets `rex do` and `rex -C` run the app's client actions.
    "rex.client.remoteControl" = true;
    "rex.server.automatic-restart-enabled" = true;
  };
}
