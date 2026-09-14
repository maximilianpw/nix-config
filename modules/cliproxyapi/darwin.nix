{currentSystemUser, ...}: {
  # Darwin clients use Kim's public CLIProxyAPI endpoint. Keep the token in a
  # runtime-only sops file so it never enters the Nix store or generated config.
  sops.secrets."cliproxyapi-public-api-key" = {
    owner = currentSystemUser;
    mode = "0400";
  };
}
