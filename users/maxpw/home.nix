# Home Manager base for every host. Profiles add their platform's modules
# through home-manager.sharedModules; files/ holds the dotfiles (managed/ is
# linked from the store by Hjem, editable/ out of store by Home Manager).
{
  config,
  lib,
  ...
}: {
  imports = [
    ../../modules/agent-tools/home.nix
    ../../modules/cliproxyapi/home.nix
    ../../modules/custom-scripts/home.nix
    ../../modules/home/dev-tools.nix
    ../../modules/fleet/home.nix
    ../../modules/home/git.nix
    ../../modules/home/gpg.nix
    ../../modules/home/jujutsu.nix
    ../../modules/home/neovim.nix
    ../../modules/home/plannotator.nix
    ../../modules/shells/home.nix
    ../../modules/sops/home.nix
    ../../modules/ssh/home.nix
    ../../modules/home/terminal-tools.nix
    ../../modules/home/tmux.nix
  ];

  _module.args.homeFiles = import ../../lib/home-files.nix {
    inherit lib;
    inherit (config.lib.file) mkOutOfStoreSymlink;
  };

  home = {
    stateVersion = "25.05";
    sessionPath = ["$HOME/.local/bin"];
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };

  xdg.enable = true;

  # Home Manager turns fontconfig on by default; only desktop profiles
  # (modules/home/fonts.nix) want it.
  fonts.fontconfig.enable = lib.mkDefault false;
}
