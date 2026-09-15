{
  config,
  isDarwin,
  isLinuxDesktop,
  pkgs,
  lib,
  ...
}: let
  settings =
    lib.recursiveUpdate
    {
      telemetry.system_info = false;
      input_server.enabled = true;
      search_files_in_root = false;
      activate_on_single_click = false;
      escape_key_behavior = "navigate_back";
      pop_on_backspace = true;
      close_on_focus_loss = true;
      pop_to_root_on_close = true;
      favicon_service = "twenty";
      keybinding = "default";

      theme = {
        light = {
          name = "catppuccin-latte";
          icon_theme = "auto";
        };
        dark = {
          name = "catppuccin-mocha";
          icon_theme = "auto";
        };
      };

      launcher_window =
        {
          opacity = 0.98;
          material = "auto";
          compact_mode.enabled = false;
          size = {
            width = 770;
            height = 480;
          };
        }
        // lib.optionalAttrs isLinuxDesktop {
          layer_shell = {
            enabled = true;
            # On-demand avoids Hyprland popup mouse issues documented upstream.
            keyboard_interactivity = "on_demand";
            layer = "top";
          };
        };

      favorites = ["clipboard:history"];
      fallbacks = ["files:search"];
      providers.calculator.preferences.backend = "numen";
    }
    (lib.optionalAttrs isDarwin {
      # Vicinae follows Qt's macOS modifier names: "control" is Command and
      # "super" is the physical Control key. Hyper combines those with Option
      # and Shift. These IDs mirror the app bundle IDs discovered by Vicinae.
      global_shortcuts.toggle = "control+SPACE";
      providers = {
        applications.entrypoints = {
          "app.legcord.Legcord".shortcut = "super+control+alt+shift+5";
          "com.1password.1password".shortcut = "super+control+alt+shift+P";
          "com.apple.Music".shortcut = "super+control+alt+shift+6";
          "com.fastmail.mac.Fastmail".shortcut = "super+control+alt+shift+M";
          "com.linear".shortcut = "super+control+alt+shift+L";
          "com.mitchellh.ghostty".shortcut = "super+control+alt+shift+3";
          "com.openai.codex".shortcut = "super+control+alt+shift+C";
          "com.tinyspeck.slackmacgap".shortcut = "super+control+alt+shift+2";
          "net.imput.helium".shortcut = "super+control+alt+shift+1";
          "notion.id".shortcut = "super+control+alt+shift+N";
        };
        clipboard.entrypoints.history.shortcut = "super+control+alt+shift+V";
      };
    });

  settingsOverride = (pkgs.formats.json {}).generate "vicinae-nix-settings.json" settings;
  configuredVicinae = pkgs.symlinkJoin {
    name = "vicinae-configured";
    meta.mainProgram = "vicinae";
    paths = [pkgs.vicinae];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/vicinae \
        --set VICINAE_OVERRIDES ${lib.escapeShellArg (toString settingsOverride)}
    '';
  };
in {
  programs.vicinae = lib.mkIf isLinuxDesktop {
    enable = true;
    package = configuredVicinae;
    systemd = {
      enable = true;
      autoStart = true;
    };
  };

  # Home Manager's bundled Vicinae module is Linux-only. On macOS the
  # notarized Homebrew app owns the executable while Home Manager owns its
  # launch agent and passes declarative settings as read-only overrides. The
  # writable settings file remains available for extension configuration.
  launchd.agents.vicinae = lib.mkIf isDarwin {
    enable = true;
    config = {
      # Launch the long-running app executable directly so it inherits the
      # declarative overrides. Starting Vicinae manually through LaunchServices
      # would otherwise omit this environment.
      ProgramArguments = [
        "/Applications/Vicinae.app/Contents/MacOS/Vicinae"
      ];
      EnvironmentVariables = {
        PATH = "${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin";
        VICINAE_NODE_BIN = lib.getExe pkgs.nodejs_24;
        VICINAE_OVERRIDES = toString settingsOverride;
      };
      RunAtLoad = true;
      KeepAlive = {
        Crashed = true;
        SuccessfulExit = false;
      };
      ProcessType = "Interactive";
    };
  };
}
