{
  config,
  isDarwin,
  isLinuxDesktop,
  pkgs,
  lib,
  ...
}: let
  settings =
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
    // lib.optionalAttrs isDarwin {
      global_shortcuts.toggle = "alt+space";

      # Vicinae follows Qt's macOS modifier names: "command" is Command and
      # "super" is the physical Control key. Together with Option and Shift,
      # this is the existing Hyper chord.
      providers.clipboard.entrypoints.history.shortcut = "command+super+alt+shift+V";
    };

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
      ProgramArguments = [
        "/opt/homebrew/bin/vicinae"
        "server"
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
