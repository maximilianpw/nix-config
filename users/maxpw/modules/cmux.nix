{
  config,
  isDarwin,
  lib,
  ...
}: let
  inherit (lib) mkIf;

  nixConfigPath = "${config.home.homeDirectory}/nix-config";

  cmuxConfig = {
    "$schema" = "https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux.schema.json";
    schemaVersion = 1;

    app = {
      appearance = "dark";
      commandPaletteSearchesAllSurfaces = true;
      confirmQuit = "dirty-only";
      forkConversationDefaultDestination = "right";
      keepWorkspaceOpenWhenClosingLastSurface = true;
      newWorkspacePlacement = "afterCurrent";
      openMarkdownInCmuxViewer = true;
      reorderOnNotification = true;
      workspaceInheritWorkingDirectory = true;
    };

    terminal = {
      autoResumeAgentSessions = true;
      rendererRealization = {
        enabled = true;
        idleSeconds = 30;
        maxWarmRenderers = 12;
      };
      showScrollBar = true;
      showTextBoxOnNewTerminals = false;
    };

    workspaceGroups = {
      newWorkspacePlacement = "afterCurrent";
      byCwd.${nixConfigPath} = {
        color = "#1565C0";
        icon = "gearshape.fill";
        newWorkspacePlacement = "afterCurrent";
      };
    };

    notifications = {
      agentIdleReminder = true;
      agentPermissionPrompt = true;
      agentTurnComplete = "whenIdle";
      dockBadge = true;
      paneFlash = true;
      showInMenuBar = true;
      sound = "default";
      unreadPaneRing = true;
    };

    sidebar = {
      branchLayout = "vertical";
      hideAllDetails = false;
      makePullRequestsClickable = true;
      openPortLinksInCmuxBrowser = true;
      openPullRequestLinksInCmuxBrowser = true;
      showBranchDirectory = true;
      showCustomMetadata = true;
      showLog = true;
      showNotificationMessage = true;
      showPorts = true;
      showProgress = true;
      showPullRequests = true;
      showSSH = true;
      showWorkspaceDescription = true;
      watchGitStatus = true;
      wrapWorkspaceTitles = false;
    };

    sidebarAppearance = {
      matchTerminalBackground = false;
      tintColor = "#0B0F14";
      tintOpacity = 0.18;
    };

    workspaceColors = {
      indicatorStyle = "leftRail";
      notificationBadgeColor = "#0A84FF";
      selectionColor = "#0A84FF";
      colors = {
        Amber = "#7D6608";
        Aqua = "#0E6B8C";
        Blue = "#1565C0";
        Brown = "#7B3F00";
        Charcoal = "#3E4B5E";
        Crimson = "#922B21";
        Green = "#196F3D";
        Indigo = "#283593";
        Magenta = "#AD1457";
        Navy = "#1A5276";
        Olive = "#4A5C18";
        Orange = "#A04000";
        Purple = "#6A1B9A";
        Red = "#C0392B";
        Rose = "#880E4F";
        Teal = "#006B6B";
        White = "#E5E7EB";
      };
    };

    automation = {
      ampIntegration = true;
      claudeCodeIntegration = true;
      cursorIntegration = true;
      geminiIntegration = true;
      portBase = 9100;
      portRange = 10;
      socketControlMode = "cmuxOnly";
      suppressSubagentNotifications = true;
      workspaceAutoNaming = false;
    };

    browser = {
      defaultSearchEngine = "google";
      discardHiddenWebViews = true;
      hiddenWebViewDiscardDelaySeconds = 300;
      hostsToOpenInEmbeddedBrowser = [
        "localhost"
        "*.localhost"
        "127.0.0.1"
        "main-pc"
        "desktop"
        "macbook-pro-m1"
      ];
      openTerminalLinksInCmuxBrowser = true;
      interceptTerminalOpenCommandInCmuxBrowser = true;
    };

    markdown = {
      fontSize = 15;
      maxWidth = 980;
    };

    diffViewer.defaultLayout = "unified";

    shortcuts.bindings = {
      focusRightSidebar = "cmd+shift+e";
      switchRightSidebarToDock = "cmd+ctrl+d";
      toggleSidebar = "cmd+b";
    };
  };

  fleetSidebar = builtins.readFile ../cmux/sidebars/fleet.swift.tpl;
in {
  config = mkIf isDarwin {
    home.activation.backupCmuxConfig = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      target="$HOME/.config/cmux/cmux.json"
      if [ -e "$target" ] && [ ! -L "$target" ]; then
        mkdir -p "$HOME/.config/cmux"
        cp -p "$target" "$target.$(date -u +%Y%m%dT%H%M%SZ).bak"
      fi
    '';

    xdg.configFile = {
      "cmux/cmux.json" = {
        force = true;
        text = builtins.toJSON cmuxConfig;
      };

      "cmux/sidebars/fleet.swift".text = fleetSidebar;
    };
  };
}
