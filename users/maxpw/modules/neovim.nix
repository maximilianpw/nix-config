{
  hostname,
  inputs,
  lib,
  pkgs,
  ...
}: let
  # Hosts whose editor has moved from chezmoi + programs.neovim to the Nixvim
  # packages in users/maxpw/neovim. Chezmoi's .chezmoiignore must exclude
  # .config/nvim and the two helper scripts for exactly these hosts; see the
  # cutover procedure in docs/nixvim-hjem-ledger.md.
  nixvimHosts = ["joyce"];
  useNixvim = lib.elem hostname nixvimHosts;

  editor = inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
  # programs.neovim's viAlias/vimAlias equivalents.
  viAliases = pkgs.runCommandLocal "nvim-vi-aliases" {} ''
    mkdir -p "$out/bin"
    ln -s ${lib.getExe editor.nvim} "$out/bin/vi"
    ln -s ${lib.getExe editor.nvim} "$out/bin/vim"
  '';
in
  lib.mkMerge [
    (lib.mkIf (!useNixvim) {
      programs.neovim = {
        enable = true;
        package = pkgs.unstable.neovim-unwrapped;
        defaultEditor = true;
        viAlias = true;
        vimAlias = true;
        vimdiffAlias = true;
        withRuby = false;
        withPython3 = false;
        # Shared with the Nixvim packages in users/maxpw/neovim.
        extraPackages = import ../neovim/tooling.nix pkgs;
      };

      xdg.configFile."nvim/init.lua".enable = lib.mkForce false;
    })

    (lib.mkIf useNixvim {
      # The same derivations `checks.<system>.nvim-candidate` tests.
      home.packages = [
        editor.nvim
        editor.nvim-vscode
        viAliases
        pkgs.lazygit-nvim-edit
        pkgs.herdr-shell
      ];
      home.shellAliases.vimdiff = "nvim -d";
      # EDITOR/VISUAL are set in home-manager.nix for every host.
    })
  ]
