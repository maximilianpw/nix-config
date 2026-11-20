# System-level shell registration (NixOS + nix-darwin) and the one definition
# of the account shell; Home Manager reads it through osConfig.
{
  config,
  lib,
  pkgs,
  ...
}: {
  options.custom.shells = {
    login = lib.mkOption {
      type = lib.types.package;
      default = pkgs.fish;
      description = ''
        Account login shell, also started by terminals and tmux panes. SSH
        remote commands are parsed by it before any interactive config runs:
        Fish accepts the `/bin/sh -c ...` wrapper tools like Codex remote SSH
        use; Nushell rejects that syntax.
      '';
    };
  };

  config = {
    programs.fish.enable = true;
    environment.shells = [
      config.custom.shells.login
      pkgs.bashInteractive
    ];
  };
}
