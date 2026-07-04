{
  config,
  inputs,
  isDarwin,
  lib,
  ...
}: let
  identityFile = "${config.home.homeDirectory}/.ssh/fleet-main-pc_ed25519";
in {
  imports = lib.optionals isDarwin [
    inputs.sops-nix.homeManagerModules.sops
  ];

  config = lib.optionalAttrs isDarwin {
    sops = {
      age.keyFile = lib.mkDefault "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      defaultSopsFile = lib.mkDefault ../../../secrets/secrets.yaml;

      secrets."fleet-main-pc-ssh-key" = {
        path = identityFile;
        mode = "0400";
      };
    };

    home.activation.ensureFleetSshDirectory = lib.hm.dag.entryBefore ["sops-nix"] ''
      ssh_dir="${config.home.homeDirectory}/.ssh"
      mkdir -p "$ssh_dir"
      chmod 700 "$ssh_dir"
    '';
  };
}
