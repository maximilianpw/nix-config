# Platform adapters supply their home path and own process restart policy.
{homeDirectory}: {
  config,
  currentSystemUser,
  ...
}: {
  sops = {
    secrets."opencode-zen-api-key" = {};
    templates."cliproxyapi.conf" = {
      owner = currentSystemUser;
      mode = "0400";
      content = (import ./config.nix).mkServerConfig {
        inherit homeDirectory;
        openCodeZenApiKey = config.sops.placeholder."opencode-zen-api-key";
      };
    };
  };
}
