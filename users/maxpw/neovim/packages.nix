# Nixvim editor packages and their behavioral check.
#
# `nvim` and `nvim-vscode` are what Home Manager installs on migrated hosts
# (users/maxpw/modules/neovim.nix), and the check runs against exactly those
# derivations. The candidates differ only by NVIM_APPNAME: they keep their own
# stdpath state so they can run beside an unmigrated editor without touching its
# sessions, undo history or breakpoints.
{
  inputs,
  system,
  toolPkgs,
}: let
  eval = profile: appName:
    inputs.nixvim.lib.evalNixvim {
      inherit system;
      modules = [(import ./default.nix {inherit profile toolPkgs appName;})];
    };

  terminal = eval "terminal" null;
  vscode = eval "vscode" null;
  inherit (terminal._module.args) pkgs;
in {
  nvim = terminal.config.build.package;
  # vscode-neovim launches this by path; the distinct name lets it share a
  # profile with the terminal editor.
  nvim-vscode = pkgs.runCommandLocal "nvim-vscode" {meta.mainProgram = "nvim-vscode";} ''
    mkdir -p "$out/bin"
    ln -s ${vscode.config.build.package}/bin/nvim "$out/bin/nvim-vscode"
  '';
  nvim-candidate = (eval "terminal" "nvim-candidate").config.build.package;
  nvim-vscode-candidate = (eval "vscode" "nvim-vscode-candidate").config.build.package;

  nvim-candidate-check =
    pkgs.runCommandLocal "nvim-candidate-check" {
      # git stands in for the user PATH: gitsigns and obsidian.nvim call it.
      nativeBuildInputs = [pkgs.bash pkgs.coreutils pkgs.findutils pkgs.gawk pkgs.gitMinimal pkgs.gnugrep pkgs.gnused];
      NVIM_TERMINAL = "${terminal.config.build.package}/bin/nvim";
      NVIM_VSCODE = "${vscode.config.build.package}/bin/nvim";
      NVIM_PLAIN = "${terminal.config.package}/bin/nvim";
      NVIM_CONFIG_SOURCE = ./config;
      NVIM_TESTS = ./tests;
    } ''
      # The Linux build sandbox has no network. macOS builds are unsandboxed
      # here; deny outbound IP traffic when the build context allows applying a
      # profile. Either way, tests/integrity.lua asserts no runtime installs.
      profile='(version 1)(allow default)(deny network-outbound (remote ip))'
      if [ -x /usr/bin/sandbox-exec ] && /usr/bin/sandbox-exec -p "$profile" /usr/bin/true 2>/dev/null; then
        /usr/bin/sandbox-exec -p "$profile" bash ${./tests/run.sh}
      else
        ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
        echo "note: sandbox-exec unavailable in this build context; network denial not enforced"
      ''}
        bash ${./tests/run.sh}
      fi
      touch "$out"
    '';
}
