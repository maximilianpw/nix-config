let
  cliProxy = rec {
    host = "127.0.0.1";
    port = 8317;
    baseUrl = "http://${host}:${toString port}";
    apiKey = "cliproxyapi-local-claudex";
    managementKeyHash = "$2b$12$NjrcwG.5nSCnzZRK0lAwAOTw0eDr.5PP1rVfd3q.YEdss3IHwP8CC";
    defaultModel = "gpt-5.6-sol";
  };
in
  cliProxy
  // {
    mkServerConfig = {homeDirectory}: ''
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

      usage-statistics-enabled: false
    '';
  }
