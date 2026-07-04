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

  cmuxDockConfig = {
    controls = [];
  };

  fleetSidebar = ''
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: "network")
          .foregroundColor("#7DD3FC")
        Text("Fleet")
          .font(.headline)
          .bold()
        Spacer()
        if unreadTotal > 0 {
          Text(String(unreadTotal))
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor("#FFFFFF")
            .padding(5)
            .background("#0A84FF")
            .cornerRadius(10)
        }
      }

      Text(selectedTitle)
        .font(.caption)
        .foregroundColor(.secondary)
        .lineLimit(1)

      Divider()

      Section("Projects") {
        Button(action: { cmux("workspace.create", name: "nix-config", cwd: "${nixConfigPath}", focus: true) }) {
          HStack(alignment: .top, spacing: 8) {
            Rectangle()
              .fill("#0A84FF")
              .frame(width: 4, height: 46)
              .cornerRadius(2)

            VStack(alignment: .leading, spacing: 2) {
              HStack(spacing: 6) {
                Image(systemName: "gearshape.fill")
                  .foregroundColor("#0A84FF")
                Text("nix-config")
                  .font(.headline)
                  .lineLimit(1)
                Spacer()
              }

              Text("${nixConfigPath}")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
          }
          .padding(6)
          .cornerRadius(8)
        }

      }

      Divider()

      Section("Machines") {
        Button(action: { cmux("workspace.create", name: "main-pc", command: "fleet ssh main-pc", focus: true) }) {
          HStack(alignment: .top, spacing: 8) {
            Rectangle()
              .fill("#9ECE6A")
              .frame(width: 4, height: 48)
              .cornerRadius(2)

            VStack(alignment: .leading, spacing: 3) {
              HStack(spacing: 6) {
                Image(systemName: "desktopcomputer")
                  .foregroundColor("#9ECE6A")
                Text("main-pc")
                  .font(.headline)
                  .lineLimit(1)
                Spacer()
                Text("tmux")
                  .font(.caption)
                  .foregroundColor("#9ECE6A")
              }

              Text("Linux workhorse")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

              Text("fleet ssh main-pc")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
          }
          .padding(6)
          .cornerRadius(8)
        }

        Button(action: { cmux("workspace.create", name: "mac", command: "fleet ssh macbook-pro-m1", focus: true) }) {
          HStack(alignment: .top, spacing: 8) {
            Rectangle()
              .fill("#7AA2F7")
              .frame(width: 4, height: 48)
              .cornerRadius(2)

            VStack(alignment: .leading, spacing: 3) {
              HStack(spacing: 6) {
                Image(systemName: "laptopcomputer")
                  .foregroundColor("#7AA2F7")
                Text("mac")
                  .font(.headline)
                  .lineLimit(1)
                Spacer()
                Text("tmux")
                  .font(.caption)
                  .foregroundColor("#7AA2F7")
              }

              Text("Interactive brain")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

              Text("fleet ssh macbook-pro-m1")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
          }
          .padding(6)
          .cornerRadius(8)
        }
      }

      Divider()

      Section("SSH") {
        ForEach(workspaces) { w in
          if let remote = w.remote {
            Button(action: { cmux("workspace.select", workspace_id: w.id) }) {
              HStack(alignment: .top, spacing: 8) {
                Rectangle()
                  .fill(remote.connected ? "#22C55E" : "#A3A3A3")
                  .frame(width: 4, height: 46)
                  .cornerRadius(2)

                VStack(alignment: .leading, spacing: 2) {
                  HStack(spacing: 6) {
                    Image(systemName: w.pinned ? "pin.fill" : "terminal")
                      .foregroundColor(w.selected ? "#FFFFFF" : .secondary)
                    Text(w.title)
                      .font(.headline)
                      .lineLimit(1)
                    Spacer()
                    if w.unread > 0 {
                      Text(String(w.unread))
                        .font(.caption)
                        .foregroundColor("#FFFFFF")
                        .padding(4)
                        .background("#0A84FF")
                        .cornerRadius(8)
                    }
                  }

                  Text(remote.target)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                  if let message = w.latestMessage {
                    Text(message)
                      .font(.caption)
                      .foregroundColor(.secondary)
                      .lineLimit(2)
                  }
                }
              }
              .padding(6)
              .cornerRadius(8)
            }
          }
        }
      }

      Divider()

      Section("Active Workspaces") {
        Reorderable(workspaces, move: "workspace.reorder") { w in
          Button(action: { cmux("workspace.select", workspace_id: w.id) }) {
            HStack(alignment: .top, spacing: 8) {
              Rectangle()
                .fill(w.selected ? "#0A84FF" : "#71717A")
                .frame(width: 4, height: 46)
                .cornerRadius(2)

              VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                  Image(systemName: w.pinned ? "pin.fill" : "folder")
                    .foregroundColor(w.selected ? "#FFFFFF" : .secondary)
                  Text(w.title)
                    .font(.headline)
                    .lineLimit(1)
                  Spacer()
                  if w.unread > 0 {
                    Text(String(w.unread))
                      .font(.caption)
                      .foregroundColor("#FFFFFF")
                      .padding(4)
                      .background("#0A84FF")
                      .cornerRadius(8)
                  }
                }

                if let branch = w.branch {
                  Text(branch)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }

                Text(w.directory)
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .lineLimit(1)

                if let message = w.latestMessage {
                  Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                }
              }
            }
            .padding(6)
            .cornerRadius(8)
          }
        }
      }
    }
    .padding(10)
  '';
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

      "cmux/dock.json".text = builtins.toJSON cmuxDockConfig;
      "cmux/sidebars/fleet.swift".text = fleetSidebar;
    };
  };
}
