# The Nixvim editor package and its behavioral check.
#
# `nvim` is what Home Manager installs (modules/home/neovim.nix): this
# configuration on the Neovim development build.
{
  inputs,
  system,
  toolPkgs,
}: let
  terminal = inputs.nixvim.lib.evalNixvim {
    inherit system;
    modules = [
      # Match the deliberate flake follows without relying on Nixvim's default.
      {nixpkgs.source = inputs.nixpkgs-unstable;}
      (import ./default.nix {
        inherit toolPkgs;
        editor = inputs.neovim-nightly-overlay.packages.${system}.default;
      })
    ];
  };
  inherit (terminal._module.args) pkgs;
in {
  nvim = terminal.config.build.package;

  nvim-check =
    pkgs.runCommandLocal "nvim-check" {
      # git stands in for the user PATH: gitsigns calls it.
      nativeBuildInputs = [pkgs.bash pkgs.coreutils pkgs.findutils pkgs.gawk pkgs.gitMinimal pkgs.gnugrep pkgs.gnused];
      NVIM_TERMINAL = "${terminal.config.build.package}/bin/nvim";
      # The unwrapped editor matching NVIM_TERMINAL, for config-only tests and
      # Neovim's own defaults.
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
