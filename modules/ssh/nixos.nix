{
  currentSystemUser,
  isLinuxDesktop,
  lib,
  ...
}: {
  # Headless hosts have no 1Password agent, so GitHub SSH uses a sops key.
  sops.secrets.github-ssh-private-key = lib.mkIf (!isLinuxDesktop) {
    owner = currentSystemUser;
    mode = "0600";
  };
}
