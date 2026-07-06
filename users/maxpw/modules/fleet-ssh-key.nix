{
  config,
  isDarwin,
  lib,
  pkgs,
  ...
}: let
  settings = import ../settings.nix {inherit pkgs;};
in {
  config = lib.mkIf isDarwin {
    # Public-key selector for the 1Password SSH agent. The private key lives in
    # 1Password; OpenSSH uses this .pub file to choose the matching agent key.
    home.file.".ssh/fleet-main-pc_ed25519.pub" = {
      text = settings.sshKeys.fleetMacbookToMainPc + "\n";
    };

    home.activation.ensureFleetSshDirectory = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      ssh_dir="${config.home.homeDirectory}/.ssh"
      mkdir -p "$ssh_dir"
      chmod 700 "$ssh_dir"
    '';
  };
}
