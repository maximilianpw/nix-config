{currentSystemUser, ...}: {
  # Proton Bridge password for this host, read at runtime by himalaya, which
  # runs as the user.
  sops.secrets.himalaya-bridge-password.owner = currentSystemUser;
}
