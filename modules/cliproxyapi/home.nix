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

  mkWrapper = {
    program,
    needsProxyKey ? false,
    env ? {},
    args ? [],
  }: let
    envValue = name: value:
      if builtins.isString value
      then lib.escapeShellArg value
      else if value ? fromEnv
      then "\"$" + value.fromEnv + "\""
      else "\"\${${name}-${value.unlessSet}}\"";
  in {
    executable = true;
    text = lib.concatLines (
      ["#!${pkgs.bash}/bin/bash"]
      ++ lib.optional needsProxyKey exportProxyApiKey
      ++ lib.mapAttrsToList (name: value: "export ${name}=${envValue name value}") env
      ++ ["exec ${lib.escapeShellArgs ([program] ++ args)} \"$@\""]
    );
  };

  claudeCode = lib.getExe pkgs.claude-code;
  anthropicProxyEnv = {
    ANTHROPIC_BASE_URL = proxyBaseUrl;
    ANTHROPIC_AUTH_TOKEN.fromEnv = "CLIPROXYAPI_API_KEY";
  };
  # Restore Claude's bundled + system CA default before the Nix package's
  # system-only fallback; macOS's system store alone can miss public roots.
  claudeCertStore.CLAUDE_CODE_CERT_STORE.unlessSet = "bundled,system";
  codexOverrides = lib.concatMap (override: ["-c" override]);

  # These shadow the package binaries of the same name so every agent CLI
  # defaults to the proxy; *-direct keeps first-party access for diagnosis.
  wrappers = {
    claude = {
      program = claudeCode;
      needsProxyKey = true;
      env = anthropicProxyEnv // claudeCertStore // {CLAUDE_CODE_MAX_CONTEXT_TOKENS = "272000";};
    };
    claude-direct = {
      program = claudeCode;
      env = claudeCertStore;
    };
    climi = {
      program = claudeCode;
      needsProxyKey = true;
      env =
        anthropicProxyEnv
        // claudeCertStore
        // {
          ANTHROPIC_DEFAULT_OPUS_MODEL = kimiModel;
          ANTHROPIC_DEFAULT_SONNET_MODEL = kimiModel;
          ANTHROPIC_DEFAULT_HAIKU_MODEL = kimiModel;
          CLAUDE_CODE_SUBAGENT_MODEL = kimiModel;
          CLAUDE_CODE_ALWAYS_ENABLE_EFFORT = "1";
          CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY = "3";
          ENABLE_TOOL_SEARCH = "false";
        };
      args = ["--model" kimiModel "--effort" "max"];
    };
    # Command-line overrides keep proxy routing declarative while leaving
    # ~/.codex/config.toml as Codex's writable persistence target.
    codex = {
      program = lib.getExe pkgs.codex;
      needsProxyKey = true;
      args = codexOverrides [
        "model=${builtins.toJSON cliProxy.defaultModel}"
        ''model_provider="cliproxyapi"''
        ''cli_auth_credentials_store="file"''
        ''mcp_oauth_credentials_store="file"''
        ''model_providers.cliproxyapi.name="CLIProxyAPI"''
        "model_providers.cliproxyapi.base_url=${builtins.toJSON "${proxyBaseUrl}/v1"}"
        ''model_providers.cliproxyapi.env_key="CLIPROXYAPI_API_KEY"''
        ''model_providers.cliproxyapi.wire_api="responses"''
      ];
    };
    codex-direct = {
      program = lib.getExe pkgs.codex;
      args = codexOverrides [
        "model=${builtins.toJSON cliProxy.defaultModel}"
        "cli_auth_credentials_store=file"
        "mcp_oauth_credentials_store=file"
      ];
    };
    grok = {
      program = lib.getExe pkgs.grok;
      needsProxyKey = true;
      env.GROK_HOME = "${config.home.homeDirectory}/.grok-cliproxyapi";
    };
    grok-direct = {
      program = lib.getExe pkgs.grok;
      args = ["--model" grokModel];
    };
    cliproxyapi-util.program = lib.getExe' quotaPackage "cliproxyapi-util";
    pi-direct = {
      program = lib.getExe pkgs.pi;
      args = ["--provider" "openai-codex" "--model" cliProxy.defaultModel];
    };
    opencode = {
      program = lib.getExe pkgs.opencode;
      needsProxyKey = true;
    };
  };
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

    file =
      {
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
      }
      // lib.mapAttrs' (name: wrapper: lib.nameValuePair ".local/bin/${name}" (mkWrapper wrapper)) wrappers;
  };
}
