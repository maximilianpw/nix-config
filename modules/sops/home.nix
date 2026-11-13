{
  config,
  inputs,
  ...
}: {
  imports = [inputs.sops-nix.homeManagerModules.sops];

  # Inert until a module declares a secret, so hosts whose secrets are all
  # system-level (Kim) can import it unconditionally.
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  };
}
