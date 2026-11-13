# System-level shell registration (NixOS + nix-darwin) and the one definition
# of the login and interactive shells; Home Manager reads them through osConfig.
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
        Account login shell. SSH remote commands are parsed by it before any
        interactive config runs: Fish accepts the `/bin/sh -c ...` wrapper
        tools like Codex remote SSH use; Nushell rejects that syntax.
      '';
    };
    interactive = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nushell;
      description = "Shell terminals and tmux panes hand off to.";
    };
  };

  config = {
    programs.fish.enable = true;
    environment.shells = [
      config.custom.shells.interactive
      config.custom.shells.login
      pkgs.bashInteractive
    ];
  };
}
