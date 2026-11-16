{currentSystemUser, ...}: {
  # Workstations restore the shared admin age identity from 1Password before
  # the first rebuild; modules/sops/home.nix reads the same key.
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/Users/${currentSystemUser}/.config/sops/age/keys.txt";
  };
}
