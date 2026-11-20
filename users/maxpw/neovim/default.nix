# Nixvim configuration for the terminal editor.
#
# `toolPkgs` supplies the language tooling (normally the system's stable package
# set, as Home Manager uses today). Plugins come from Nixvim's own package set,
# which follows nixpkgs-unstable; `editor` is the unwrapped Neovim to wrap.
{
  toolPkgs,
  editor,
}: {
  lib,
  pkgs,
  ...
}: let
  pluginSet = import ./plugins.nix {inherit lib pkgs;};
  inherit (pluginSet) plugins;

  # Libraries every plugin may require without an explicit packadd.
  startNames = [
    "nui.nvim"
    "nvim-web-devicons"
    "plenary.nvim"
    "schemastore.nvim"
  ];
  optNames = lib.subtractLists startNames (lib.attrNames plugins);

  # Only the runtime tree; tests and docs stay out of the deployed config.
  runtimeConfig = lib.fileset.toSource {
    root = ./config;
    fileset = lib.fileset.unions [./config/lua ./config/after];
  };

  lazygitNvimEdit = pkgs.callPackage ../../../packages/lazygit-nvim-edit.nix {};
in {
  imports = [./options.nix];

  package = editor;
  wrapRc = true;
  # Keep ~/.config/nvim and stdpath("data")/site off the runtimepath so the old
  # chezmoi-deployed tree and lazy.nvim-era parsers can never be loaded.
  impureRtp = false;
  withRuby = false;
  withPython3 = false;
  withNodeJs = false;
  withPerl = false;

  plugins.lz-n.enable = true;

  extraPlugins =
    pluginSet.treesitterRuntime
    ++ map (name: plugins.${name}) startNames
    ++ map (name: {
      plugin = plugins.${name};
      optional = true;
    })
    optNames;

  extraPackages = import ./tooling.nix toolPkgs;

  globals = {
    maxpw_nvim_config_dir = "${runtimeConfig}";
    maxpw_treesitter_parsers = pluginSet.treesitterParsers;
    maxpw_lazygit_nvim_edit = lib.getExe lazygitNvimEdit;
  };

  extraConfigLuaPre = ''
    -- impureRtp = false still leaves XDG config/data "site" directories on both
    -- paths, so a stale ~/.local/share/nvim/site/{parser,plugin,pack} from the
    -- lazy.nvim era would load. Everything this editor needs is in the store.
    for _, option in ipairs({ "runtimepath", "packpath" }) do
      local pure = vim.tbl_filter(function(dir)
        return vim.startswith(dir, "/nix/store/")
      end, vim.split(vim.o[option], ",", { plain = true }))
      vim.o[option] = table.concat(pure, ",")
    end

    -- First, so lua/ shadows plugin modules of the same name. lsp/<name>.lua
    -- files are merged in runtimepath order instead, with later ones winning,
    -- so overrides of nvim-lspconfig live in after/lsp/.
    vim.opt.rtp:prepend("${runtimeConfig}")
    vim.opt.rtp:append("${runtimeConfig}/after")
  '';

  extraConfigLua = ''
    require("config")
  '';
}
