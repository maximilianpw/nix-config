{currentSystemUser, ...}: {
  # Hosts with system-level sops hold the key here; modules/agent-tools/home.nix
  # declares it through Home Manager sops elsewhere.
  sops.secrets.linear-api-key = {
    owner = currentSystemUser;
    mode = "0400";
  };
}
