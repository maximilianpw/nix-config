{
  inputs,
  lib,
  pkgs,
  ...
}: let
  editor = inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
  # programs.neovim's viAlias/vimAlias equivalents.
  viAliases = pkgs.runCommandLocal "nvim-vi-aliases" {} ''
    mkdir -p "$out/bin"
    ln -s ${lib.getExe editor.nvim} "$out/bin/vi"
    ln -s ${lib.getExe editor.nvim} "$out/bin/vim"
  '';
in {
  # The same derivations `checks.<system>.nvim-candidate` and `nvim-stable` test.
  home.packages = [
    editor.nvim
    editor.nvim-stable
    editor.nvim-vscode
    viAliases
    pkgs.lazygit-nvim-edit
  ];
  home.shellAliases.vimdiff = "nvim -d";
  # EDITOR/VISUAL are set in users/maxpw/home.nix for every host.
}
