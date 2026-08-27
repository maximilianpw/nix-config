let
  openCodeZen = {
    baseUrl = "https://opencode.ai/zen/v1";
    prefix = "zen";
    chatModels = [
      {
        id = "deepseek-v4-pro";
        displayName = "DeepSeek V4 Pro";
        contextLength = 1000000;
        inputModalities = ["text"];
      }
      {
        id = "deepseek-v4-flash";
        displayName = "DeepSeek V4 Flash";
        contextLength = 1000000;
        inputModalities = ["text"];
      }
      {
        id = "glm-5.2";
        displayName = "GLM-5.2";
        contextLength = 1000000;
        inputModalities = ["text"];
      }
      {
        id = "glm-5.1";
        displayName = "GLM-5.1";
        contextLength = 204800;
        inputModalities = ["text"];
      }
      {
        id = "minimax-m3";
        displayName = "MiniMax-M3";
        contextLength = 512000;
        inputModalities = ["text" "image"];
      }
      {
        id = "minimax-m2.7";
        displayName = "MiniMax-M2.7";
        contextLength = 204800;
        inputModalities = ["text"];
      }
      {
        id = "kimi-k3";
        displayName = "Kimi K3";
        contextLength = 1048576;
        inputModalities = ["text" "image"];
      }
      {
        id = "kimi-k2.7-code";
        displayName = "Kimi K2.7 Code";
        contextLength = 262144;
        inputModalities = ["text" "image"];
      }
      {
        id = "kimi-k2.6";
        displayName = "Kimi K2.6";
        contextLength = 262144;
        inputModalities = ["text" "image"];
      }
      {
        id = "big-pickle";
        displayName = "Big Pickle";
        contextLength = 200000;
        inputModalities = ["text"];
      }
      {
        id = "mimo-v2.5-free";
        displayName = "MiMo V2.5 Free";
        contextLength = 200000;
        inputModalities = ["text" "image"];
      }
      {
        id = "hy3-free";
        displayName = "Hy3 Free";
        contextLength = 190000;
        inputModalities = ["text"];
      }
      {
        id = "nemotron-3-ultra-free";
        displayName = "Nemotron 3 Ultra Free";
        contextLength = 1000000;
        inputModalities = ["text"];
      }
      {
        id = "nemotron-3.5-lightning-free";
        displayName = "Nemotron 3.5 Lightning Free";
        contextLength = 262144;
        inputModalities = ["text"];
      }
    ];
  };

  cliProxy = rec {
    host = "127.0.0.1";
    port = 8317;
    baseUrl = "http://${host}:${toString port}";
    apiKey = "cliproxyapi-local-claudex";
    managementKeyHash = "$2b$12$NjrcwG.5nSCnzZRK0lAwAOTw0eDr.5PP1rVfd3q.YEdss3IHwP8CC";
    defaultModel = "gpt-5.6-sol";
    inherit openCodeZen;
  };

  renderZenModel = model:
    "      - name: \"${model.id}\"\n"
    + "        alias: \"${model.id}\"\n"
    + "        display-name: \"${model.displayName}\"\n"
    + "        max-context-length: ${toString model.contextLength}\n"
    + "        input-modalities: [${builtins.concatStringsSep ", " model.inputModalities}]\n"
    + "        output-modalities: [text]\n";
in
  cliProxy
  // {
    mkServerConfig = {
      homeDirectory,
      openCodeZenApiKey,
    }: ''
      host: "${cliProxy.host}"
      port: ${toString cliProxy.port}
      auth-dir: "${homeDirectory}/.cli-proxy-api"

      api-keys:
        - "${cliProxy.apiKey}"

      remote-management:
        allow-remote: false
        secret-key: "${cliProxy.managementKeyHash}"

      routing:
        strategy: weighted-round-robin
        session-affinity: true
        session-affinity-ttl: "1h"

      # Zen reuses model IDs served by the OAuth providers. Require its `zen/`
      # prefix so adding this fallback cannot change existing model routing.
      force-model-prefix: true

      openai-compatibility:
        - name: "opencode-zen"
          prefix: "${openCodeZen.prefix}"
          base-url: "${openCodeZen.baseUrl}"
          api-key-entries:
            - api-key: "${openCodeZenApiKey}"
          models:
      ${builtins.concatStringsSep "" (map renderZenModel openCodeZen.chatModels)}
      usage-statistics-enabled: false
    '';
  }
