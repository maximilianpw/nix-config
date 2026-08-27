{agentConfigDirectory}: {
  config,
  lib,
  pkgs,
  ...
}: let
  cliProxy = import ./config.nix;
  jsonFormat = pkgs.formats.json {};
  kimiModel = "kimi-k3";
  grokModel = "grok-4.6";
  directOpenCodeModel = "openai/gpt-5.5";

  opencodeConfig =
    lib.recursiveUpdate
    (builtins.fromJSON (builtins.readFile (agentConfigDirectory + "/opencode/cliproxyapi.json")))
    {
      model = "cliproxyapi/${cliProxy.defaultModel}";
      provider.cliproxyapi = {
        options = {
          baseURL = "${cliProxy.baseUrl}/v1";
          inherit (cliProxy) apiKey;
        };
        models = builtins.listToAttrs (
          map (model: {
            name = "${cliProxy.openCodeZen.prefix}/${model.id}";
            value = {
              name = "${model.displayName} via OpenCode Zen";
              reasoning = true;
              tool_call = true;
              limit.context = model.contextLength;
              modalities = {
                input = model.inputModalities;
                output = ["text"];
              };
            };
          })
          cliProxy.openCodeZen.chatModels
        );
      };
    };

  grokProxyModel = "cliproxyapi-${grokModel}";
  grokProxyConfig =
    lib.replaceStrings
    ["default = \"${grokModel}\"" "web_search = \"${grokModel}\""]
    ["default = \"${grokProxyModel}\"" "web_search = \"${grokProxyModel}\""]
    (builtins.readFile (agentConfigDirectory + "/grok/config.toml"))
    + ''

      [model."${grokProxyModel}"]
      model = "${grokModel}"
      base_url = "${cliProxy.baseUrl}/v1"
      name = "Grok 4.6 via CLIProxyAPI"
      api_backend = "chat_completions"
      env_key = "CLIPROXYAPI_API_KEY"
      context_window = 500000
    '';
in {
  home.file = {
    ".codex/cliproxyapi.config.toml".text = ''
      model = "${cliProxy.defaultModel}"
      model_provider = "cliproxyapi"
      cli_auth_credentials_store = "file"
      mcp_oauth_credentials_store = "file"

      [model_providers.cliproxyapi]
      name = "CLIProxyAPI"
      base_url = "${cliProxy.baseUrl}/v1"
      env_key = "CLIPROXYAPI_API_KEY"
      wire_api = "responses"
    '';

    ".grok-cliproxyapi/config.toml".text = grokProxyConfig;
    ".config/opencode/opencode.json".source = jsonFormat.generate "opencode.json" opencodeConfig;

    # Put proxy-default wrappers ahead of package binaries. The matching
    # *-direct commands keep first-party access available for diagnosis.
    ".local/bin/claude" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        export ANTHROPIC_BASE_URL=${lib.escapeShellArg cliProxy.baseUrl}
        export ANTHROPIC_AUTH_TOKEN=${lib.escapeShellArg cliProxy.apiKey}
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
    ".local/bin/climi" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        export ANTHROPIC_BASE_URL=${lib.escapeShellArg cliProxy.baseUrl}
        export ANTHROPIC_AUTH_TOKEN=${lib.escapeShellArg cliProxy.apiKey}
        export ANTHROPIC_DEFAULT_OPUS_MODEL=${kimiModel} ANTHROPIC_DEFAULT_SONNET_MODEL=${kimiModel} ANTHROPIC_DEFAULT_HAIKU_MODEL=${kimiModel}
        export CLAUDE_CODE_SUBAGENT_MODEL=${kimiModel} CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1
        export CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=3 ENABLE_TOOL_SEARCH=false
        exec ${lib.getExe pkgs.claude-code} --model ${kimiModel} --effort max "$@"
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
        exec ${lib.getExe pkgs.codex} -c cli_auth_credentials_store=file -c mcp_oauth_credentials_store=file "$@"
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
        exec ${lib.getExe pkgs.grok} --model ${grokModel} "$@"
      '';
    };
    ".local/bin/cliproxyapi-util" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        exec ${lib.getExe pkgs.bun} ${lib.escapeShellArg "${config.home.homeDirectory}/pi-config/cli/cliproxyapi-util.ts"} "$@"
      '';
    };
    ".local/bin/pi-direct" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        exec ${lib.getExe pkgs.pi} --provider openai-codex --model ${lib.escapeShellArg cliProxy.defaultModel} "$@"
      '';
    };
    ".local/bin/opencode-direct" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        exec ${lib.getExe pkgs.opencode} --model ${directOpenCodeModel} "$@"
      '';
    };
  };
}
