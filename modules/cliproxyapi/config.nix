let
  openCodeZen = {
    baseUrl = "https://opencode.ai/inference/openai/v1";
    prefix = "zen";
    # Token limits follow the OpenCode provider catalog at https://models.dev/api.json.
    # OpenCode rejects its free tier through this proxy. Use the native
    # OpenCode provider for free models; keep this upstream for paid models.
    chatModels = [
      {
        id = "deepseek-v4-pro";
        displayName = "DeepSeek V4 Pro";
        contextLength = 1000000;
        outputLength = 384000;
        inputModalities = ["text"];
      }
      {
        id = "deepseek-v4-flash";
        displayName = "DeepSeek V4 Flash";
        contextLength = 1000000;
        outputLength = 384000;
        inputModalities = ["text"];
      }
      {
        id = "glm-5.2";
        displayName = "GLM-5.2";
        contextLength = 1000000;
        outputLength = 131072;
        inputModalities = ["text"];
      }
      {
        id = "minimax-m3";
        displayName = "MiniMax-M3";
        contextLength = 512000;
        outputLength = 128000;
        inputModalities = ["text" "image"];
      }
      {
        id = "kimi-k3";
        displayName = "Kimi K3";
        contextLength = 1048576;
        outputLength = 131072;
        inputModalities = ["text" "image"];
      }
    ];
  };

  cliProxy = rec {
    host = "127.0.0.1";
    port = 8317;
    baseUrl = "http://${host}:${toString port}";
    publicBaseUrl = "https://cliproxy.maximilian.pw";
    # Fleet's quota-only loopback endpoint on the server host. nginx exposes
    # it publicly at ${publicBaseUrl}/quota/v1/ behind the public API key.
    quotaPort = 8318;
    quotaBaseUrl = "http://${host}:${toString quotaPort}";
    publicApiKeyPath = "/run/secrets/cliproxyapi-public-api-key";
    localApiKeyPath = "/run/secrets/cliproxyapi-local-api-key";
    managementKeyHash = "$2b$12$NjrcwG.5nSCnzZRK0lAwAOTw0eDr.5PP1rVfd3q.YEdss3IHwP8CC";
    defaultModel = "gpt-6-astra";
    inherit openCodeZen;
  };

  renderZenModel = model:
    "        - name: \"${model.id}\"\n"
    + "          alias: \"${model.id}\"\n"
    + "          display-name: \"${model.displayName}\"\n"
    + "          max-context-length: ${toString model.contextLength}\n"
    + "          input-modalities: [${builtins.concatStringsSep ", " model.inputModalities}]\n"
    + "          output-modalities: [text]\n";
in
  cliProxy
  // {
    mkServerConfig = {
      homeDirectory,
      localApiKey,
      openCodeZenApiKey,
    }: ''
      # CLIProxyAPI v8 layout. A present v8 field wins over its legacy spelling,
      # so do not reintroduce legacy top-level keys alongside these.
      config-version: 8

      server:
        host: "${cliProxy.host}"
        port: ${toString cliProxy.port}

      management:
        allow-remote: true
        secret-key: "${cliProxy.managementKeyHash}"

      access:
        api-keys:
          - "${localApiKey}"

      oauth:
        auth-dir: "${homeDirectory}/.cli-proxy-api"

      routing:
        strategy: weighted-round-robin
        # Keep a client session on one credential so provider prompt caches
        # stay warm; subagents inherit the parent's credential (default).
        session-affinity: true
        session-affinity-ttl: "1h"
        # Zen reuses model IDs served by the OAuth providers. Require its `zen/`
        # prefix so this upstream cannot change existing model routing.
        force-model-prefix: true

      requests:
        streaming:
          # Remote clients reach this through Cloudflare, which drops streams
          # idle for about 100 seconds, e.g. during long silent reasoning.
          keepalive-seconds: 15
          # Retry on another credential when a stream fails before its first byte.
          bootstrap-retries: 1

      # With two accounts per provider, one model's quota limit should not
      # bench the whole credential for every other model.
      upstream:
        codex:
          model-level-cooling: true
        claude:
          model-level-cooling: true

      api-keys:
        openai-compatibility:
          - name: "opencode-zen"
            prefix: "${openCodeZen.prefix}"
            base-url: "${openCodeZen.baseUrl}"
            keys:
              - api-key: "${openCodeZenApiKey}"
            models:
      ${builtins.concatStringsSep "" (map renderZenModel openCodeZen.chatModels)}
      observability:
        usage:
          usage-statistics-enabled: false
    '';
  }
