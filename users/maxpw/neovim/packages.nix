# Nixvim editor packages and their behavioral checks.
#
# `nvim`, `nvim-stable` and `nvim-vscode` are what Home Manager installs on
# migrated hosts (users/maxpw/modules/neovim.nix). The terminal `nvim` runs the
# Neovim development build; `nvim-stable` is the same configuration on the
# release editor, kept as a fallback that shares the terminal editor's state.
# VS Code stays on the release editor. The candidates differ only by
# NVIM_APPNAME: they keep their own stdpath state so they can run beside an
# unmigrated editor without touching its sessions, undo history or breakpoints.
{
  inputs,
  system,
  toolPkgs,
}: let
  nightly = inputs.neovim-nightly-overlay.packages.${system}.default;

  eval = profile: appName: editor:
    inputs.nixvim.lib.evalNixvim {
      inherit system;
      modules = [
        # Match the deliberate flake follows without relying on Nixvim's default.
        {nixpkgs.source = inputs.nixpkgs-unstable;}
        (import ./default.nix {inherit profile toolPkgs appName editor;})
      ];
    };

  terminal = eval "terminal" null nightly;
  terminalStable = eval "terminal" null null;
  vscode = eval "vscode" null null;
  inherit (terminal._module.args) pkgs;

  # Another command name for an editor package; state still follows its
  # NVIM_APPNAME, so a renamed editor shares the default profile.
  rename = name: package:
    pkgs.runCommandLocal name {meta.mainProgram = name;} ''
      mkdir -p "$out/bin"
      ln -s ${package}/bin/nvim "$out/bin/${name}"
    '';

  check = name: terminalEval:
    pkgs.runCommandLocal name {
      # git stands in for the user PATH: gitsigns and obsidian.nvim call it.
      nativeBuildInputs = [pkgs.bash pkgs.coreutils pkgs.findutils pkgs.gawk pkgs.gitMinimal pkgs.gnugrep pkgs.gnused];
      NVIM_TERMINAL = "${terminalEval.config.build.package}/bin/nvim";
      NVIM_VSCODE = "${vscode.config.build.package}/bin/nvim";
      # The unwrapped editor matching NVIM_TERMINAL, for config-only tests and
      # Neovim's own defaults.
      NVIM_PLAIN = "${terminalEval.config.package}/bin/nvim";
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
in {
  nvim = terminal.config.build.package;
  nvim-stable = rename "nvim-stable" terminalStable.config.build.package;
  # vscode-neovim launches this by path; the distinct name lets it share a
  # profile with the terminal editor.
  nvim-vscode = rename "nvim-vscode" vscode.config.build.package;
  nvim-candidate = (eval "terminal" "nvim-candidate" nightly).config.build.package;
  nvim-vscode-candidate = (eval "vscode" "nvim-vscode-candidate" null).config.build.package;

  nvim-candidate-check = check "nvim-candidate-check" terminal;
  nvim-stable-check = check "nvim-stable-check" terminalStable;
}
