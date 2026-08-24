{
  config,
  currentSystemUserDir,
  pkgs,
  lib,
  ...
}: let
  homeFiles = import ../../../lib/home-files.nix {
    inherit lib;
    mkOutOfStoreSymlink = config.lib.file.mkOutOfStoreSymlink;
  };

  source = path: homeFiles.mkRepoSource config.home.homeDirectory "users/${currentSystemUserDir}/agents/${path}";
  piConfigSource = path: homeFiles.mkHomeSource config.home.homeDirectory "pi-config/${path}";
  inherit (import ../settings.nix {inherit pkgs;}) cliProxy;

  grokProxyModel = "cliproxyapi-grok-4.6";
  grokProxyConfig =
    lib.replaceStrings
    ["default = \"grok-4.6\"" "web_search = \"grok-4.6\""]
    ["default = \"${grokProxyModel}\"" "web_search = \"${grokProxyModel}\""]
    (builtins.readFile ../agents/grok/config.toml)
    + ''

      [model."${grokProxyModel}"]
      model = "grok-4.6"
      base_url = "${cliProxy.baseUrl}/v1"
      name = "Grok 4.6 via CLIProxyAPI"
      api_backend = "chat_completions"
      env_key = "CLIPROXYAPI_API_KEY"
      context_window = 500000
    '';
in {
  home = {
    packages = [
      pkgs.claude-code
      pkgs.codex
      pkgs.opencode
      pkgs.grok
      pkgs.herdr
      pkgs.amp-cli
      pkgs.pi
      pkgs.skills
    ];

    file = {
      ".config/amp/settings.json".source = source "amp/settings.json";
      ".codex/AGENTS.md".source = source "shared/AGENTS.md";
      ".codex/cliproxyapi.config.toml".text = ''
        model = "${cliProxy.model}"
        model_provider = "cliproxyapi"

        [model_providers.cliproxyapi]
        name = "CLIProxyAPI"
        base_url = "${cliProxy.baseUrl}/v1"
        env_key = "CLIPROXYAPI_API_KEY"
        wire_api = "responses"
      '';
      ".claude/CLAUDE.md".source = source "shared/AGENTS.md";
      ".config/opencode/AGENTS.md".source = source "shared/AGENTS.md";
      ".pi/agent/AGENTS.md".source = source "shared/AGENTS.md";
      ".claude/settings.json".source = source "claude/settings.json";
      ".grok/config.toml" = {
        source = source "grok/config.toml";
        force = true;
      };
      ".grok-cliproxyapi/config.toml".text = grokProxyConfig;

      ".config/opencode/opencode.json".source = source "opencode/opencode.json";

      ".pi/agent/settings.json".source = piConfigSource "settings.json";
      ".pi/agent/models.json".source = piConfigSource "models.json";
      ".pi/agent/cloak.json".source = piConfigSource "cloak.json";
      ".pi/agent/extensions" = {
        source = piConfigSource "extensions";
        recursive = true;
      };
      ".pi/agent/prompts" = {
        source = piConfigSource "prompts";
        recursive = true;
      };
      ".pi/agent/themes" = {
        source = piConfigSource "themes";
        recursive = true;
      };

      # Put proxy-default wrappers ahead of package binaries. The matching
      # *-direct commands keep first-party access available for diagnosis.
      ".local/bin/claude" = {
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          export ANTHROPIC_BASE_URL=${lib.escapeShellArg cliProxy.baseUrl}
          export ANTHROPIC_AUTH_TOKEN=${lib.escapeShellArg cliProxy.apiKey}
          export ANTHROPIC_MODEL=${lib.escapeShellArg cliProxy.model}
          export ANTHROPIC_DEFAULT_OPUS_MODEL=${lib.escapeShellArg cliProxy.model}
          export ANTHROPIC_DEFAULT_SONNET_MODEL=${lib.escapeShellArg cliProxy.model}
          export ANTHROPIC_DEFAULT_HAIKU_MODEL=${lib.escapeShellArg cliProxy.model}
          export CLAUDE_CODE_SUBAGENT_MODEL=${lib.escapeShellArg cliProxy.model}
          export CLAUDE_CODE_MAX_CONTEXT_TOKENS=272000
          exec ${lib.getExe pkgs.claude-code} "$@"
        '';
      };
      ".local/bin/claude-direct" = {
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          exec ${lib.getExe pkgs.claude-code} "$@"
        '';
      };
      ".local/bin/codex" = {
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          export CLIPROXYAPI_API_KEY=${lib.escapeShellArg cliProxy.apiKey}
          exec ${lib.getExe pkgs.codex} --profile cliproxyapi "$@"
        '';
      };
      ".local/bin/codex-direct" = {
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          exec ${lib.getExe pkgs.codex} "$@"
        '';
      };
      ".local/bin/grok" = {
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          export CLIPROXYAPI_API_KEY=${lib.escapeShellArg cliProxy.apiKey}
          export GROK_HOME=${lib.escapeShellArg "${config.home.homeDirectory}/.grok-cliproxyapi"}
          exec ${lib.getExe pkgs.grok} "$@"
        '';
      };
      ".local/bin/grok-direct" = {
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          exec ${lib.getExe pkgs.grok} --model grok-4.6 "$@"
        '';
      };
      ".local/bin/pi-direct" = {
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          exec ${lib.getExe pkgs.pi} --provider openai-codex --model ${lib.escapeShellArg cliProxy.model} "$@"
        '';
      };
      ".local/bin/opencode" = {
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          exec ${lib.getExe pkgs.opencode} --model ${lib.escapeShellArg "cliproxyapi/${cliProxy.model}"} "$@"
        '';
      };
      ".local/bin/opencode-direct" = {
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          exec ${lib.getExe pkgs.opencode} --model openai/gpt-5.5 "$@"
        '';
      };
    };
  };
}
