{agentConfigDirectory}: {
  config,
  currentSystemName,
  lib,
  pkgs,
  ...
}: let
  cliProxy = import ./config.nix;
  useLocalProxy = currentSystemName == "kim";
  proxyBaseUrl =
    if useLocalProxy
    then cliProxy.baseUrl
    else cliProxy.publicBaseUrl;
  proxyApiKey =
    if useLocalProxy
    then cliProxy.apiKey
    else "{env:CLIPROXYAPI_API_KEY}";
  exportProxyApiKey =
    if useLocalProxy
    then "export CLIPROXYAPI_API_KEY=${lib.escapeShellArg cliProxy.apiKey}"
    else "export CLIPROXYAPI_API_KEY=\"$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg cliProxy.publicApiKeyPath})\"";
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
          baseURL = "${proxyBaseUrl}/v1";
          apiKey = proxyApiKey;
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
      base_url = "${proxyBaseUrl}/v1"
      name = "Grok 4.6 via CLIProxyAPI"
      api_backend = "chat_completions"
      env_key = "CLIPROXYAPI_API_KEY"
      context_window = 500000
    '';
in {
  home.sessionVariables = {
    CLIPROXYAPI_ROOT_URL = proxyBaseUrl;
    CLIPROXYAPI_API_KEY_FILE = lib.mkIf (!useLocalProxy) cliProxy.publicApiKeyPath;
    CLIPROXYAPI_API_KEY = lib.mkIf useLocalProxy cliProxy.apiKey;
  };

  home.file = {
    ".grok-cliproxyapi/config.toml".text = grokProxyConfig;
    ".config/opencode/opencode.json".source = jsonFormat.generate "opencode.json" opencodeConfig;

    # Put proxy-default wrappers ahead of package binaries. The matching
    # *-direct commands keep first-party access available for diagnosis.
    ".local/bin/claude" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        ${exportProxyApiKey}
        export ANTHROPIC_BASE_URL=${lib.escapeShellArg proxyBaseUrl}
        export ANTHROPIC_AUTH_TOKEN="$CLIPROXYAPI_API_KEY"
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
        ${exportProxyApiKey}
        export ANTHROPIC_BASE_URL=${lib.escapeShellArg proxyBaseUrl}
        export ANTHROPIC_AUTH_TOKEN="$CLIPROXYAPI_API_KEY"
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
        ${exportProxyApiKey}

        # Command-line overrides keep proxy routing declarative while leaving
        # ~/.codex/config.toml as Codex's writable persistence target.
        exec ${lib.getExe pkgs.codex} \
          -c ${lib.escapeShellArg "model=${builtins.toJSON cliProxy.defaultModel}"} \
          -c ${lib.escapeShellArg "model_provider=\"cliproxyapi\""} \
          -c ${lib.escapeShellArg "cli_auth_credentials_store=\"file\""} \
          -c ${lib.escapeShellArg "mcp_oauth_credentials_store=\"file\""} \
          -c ${lib.escapeShellArg "model_providers.cliproxyapi.name=\"CLIProxyAPI\""} \
          -c ${lib.escapeShellArg "model_providers.cliproxyapi.base_url=${builtins.toJSON "${proxyBaseUrl}/v1"}"} \
          -c ${lib.escapeShellArg "model_providers.cliproxyapi.env_key=\"CLIPROXYAPI_API_KEY\""} \
          -c ${lib.escapeShellArg "model_providers.cliproxyapi.wire_api=\"responses\""} \
          "$@"
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
        ${exportProxyApiKey}
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
    ".local/bin/opencode" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        ${exportProxyApiKey}
        exec ${lib.getExe pkgs.opencode} "$@"
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
