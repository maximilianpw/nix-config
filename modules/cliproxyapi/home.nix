{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cliProxy = import ./config.nix;
  agentConfigDirectory = ../../users/maxpw/files/editable/agents;
  useLocalProxy = config.custom.cliproxyapi.endpoint == "local";
  proxyBaseUrl =
    if useLocalProxy
    then cliProxy.baseUrl
    else cliProxy.publicBaseUrl;
  proxyApiKeyPath =
    if useLocalProxy
    then cliProxy.localApiKeyPath
    else cliProxy.publicApiKeyPath;
  # Kim reads its own loopback quota endpoint; other hosts use the public one.
  quotaUrl =
    if useLocalProxy
    then "${cliProxy.quotaBaseUrl}/quota/v1"
    else "${cliProxy.publicBaseUrl}/quota/v1";
  quotaPackage = inputs.fleet.packages.${pkgs.stdenv.hostPlatform.system}.cliproxy-quota;
  proxyApiKey = "{env:CLIPROXYAPI_API_KEY}";
  exportProxyApiKey = "export CLIPROXYAPI_API_KEY=\"$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg proxyApiKeyPath})\"";
  jsonFormat = pkgs.formats.json {};
  kimiModel = "kimi-k3";
  grokModel = "grok-4.6";
  opencodeCliDefaults = agentConfigDirectory + "/opencode/cli.json";
  configureOpenCodeCli = pkgs.writeShellApplication {
    name = "opencode-configure-cli";
    runtimeInputs = [pkgs.jq pkgs.coreutils];
    text = builtins.readFile ./opencode-configure-cli.sh;
  };

  opencodeConfig =
    lib.recursiveUpdate
    (builtins.fromJSON (builtins.readFile (agentConfigDirectory + "/opencode/cliproxyapi.json")))
    {
      model = "cliproxyapi/${cliProxy.defaultModel}";
      providers.cliproxyapi = {
        settings = {
          baseURL = "${proxyBaseUrl}/v1";
          apiKey = proxyApiKey;
        };
        models = builtins.listToAttrs (
          map (model: {
            name = "${cliProxy.openCodeZen.prefix}/${model.id}";
            value = {
              name = "${model.displayName} via OpenCode Zen";
              capabilities = {
                tools = true;
                input = model.inputModalities;
                output = ["text"];
              };
              limit = {
                context = model.contextLength;
                output = model.outputLength;
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
  options.custom.cliproxyapi.endpoint = lib.mkOption {
    type = lib.types.enum ["local" "public"];
    default = "public";
    description = "Which CLIProxyAPI the agent CLIs talk to: the loopback server on this host, or Kim's public endpoint.";
  };

  config.home = {
    sessionVariables = {
      CLIPROXYAPI_ROOT_URL = proxyBaseUrl;
      CLIPROXYAPI_API_KEY_FILE = proxyApiKeyPath;
      # pi-claude-code injects its own relay as ANTHROPIC_BASE_URL; the
      # proxy-default `claude` wrapper would overwrite it.
      PI_CLAUDE_CODE_COMMAND = "${config.home.homeDirectory}/.local/bin/claude-direct";
    };

    # cli.json is also written by OpenCode and Herdr. Merge the declared keys
    # during activation instead of replacing it with an immutable store symlink.
    activation.configureOpenCodeCli = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run ${lib.getExe configureOpenCodeCli} ${opencodeCliDefaults} ${lib.escapeShellArg "${config.home.homeDirectory}/.config/opencode/cli.json"}
    '';

    file = {
      ".config/cliproxyapi/client.json" = {
        force = true;
        source = jsonFormat.generate "cliproxyapi-client.json" {
          rootUrl = proxyBaseUrl;
          inherit quotaUrl;
          apiKeyFile = proxyApiKeyPath;
        };
      };
      ".grok-cliproxyapi/config.toml".text = grokProxyConfig;
      ".config/opencode/opencode.json".source = jsonFormat.generate "opencode.json" opencodeConfig;
      ".config/opencode/opencode-quota/quota-toast.json".source = agentConfigDirectory + "/opencode/quota-toast.json";

      # Put proxy-default wrappers ahead of package binaries. The matching
      # *-direct commands keep first-party access available for diagnosis.
      # Restore Claude's bundled + system CA default before the Nix package's
      # system-only fallback; macOS's system store alone can miss public roots.
      ".local/bin/claude" = {
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          ${exportProxyApiKey}
          export ANTHROPIC_BASE_URL=${lib.escapeShellArg proxyBaseUrl}
          export ANTHROPIC_AUTH_TOKEN="$CLIPROXYAPI_API_KEY"
          export CLAUDE_CODE_MAX_CONTEXT_TOKENS=272000
          export CLAUDE_CODE_CERT_STORE="''${CLAUDE_CODE_CERT_STORE-bundled,system}"
          exec ${lib.getExe pkgs.claude-code} "$@"
        '';
      };
      ".local/bin/claude-direct" = {
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          export CLAUDE_CODE_CERT_STORE="''${CLAUDE_CODE_CERT_STORE-bundled,system}"
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
          export CLAUDE_CODE_CERT_STORE="''${CLAUDE_CODE_CERT_STORE-bundled,system}"
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
          exec ${lib.getExe pkgs.codex} \
            -c ${lib.escapeShellArg "model=${builtins.toJSON cliProxy.defaultModel}"} \
            -c cli_auth_credentials_store=file -c mcp_oauth_credentials_store=file "$@"
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
          exec ${lib.getExe' quotaPackage "cliproxyapi-util"} "$@"
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
    };
  };
}
