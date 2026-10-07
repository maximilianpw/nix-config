# Nixvim configuration shared by both editor packages:
#
# - "terminal": the full editor.
# - "vscode": the reduced editor launched by vscode-neovim. It ships only the
#   editing primitives in lua/config/plugins.lua `M.shared`, so terminal plugin
#   runtime files and mappings cannot leak into VS Code.
#
# `toolPkgs` supplies the language tooling (normally the system's stable package
# set, as Home Manager uses today). Neovim and its plugins come from Nixvim's own
# package set, which follows nixpkgs-unstable. `appName` isolates
# stdpath(data/state/cache) for side-by-side candidates; null means "nvim".
{
  profile,
  toolPkgs,
  appName ? null,
}: {
  lib,
  pkgs,
  ...
}: let
  pluginSet = import ./plugins.nix {inherit lib pkgs;};
  inherit (pluginSet) plugins;

  vscodePlugins = [
    "mini.nvim"
    "flash.nvim"
    "nvim-treesitter"
    "nvim-treesitter-textobjects"
    "ts-comments.nvim"
  ];

  # Libraries every terminal plugin may require without an explicit packadd.
  terminalStartPlugins = [
    "nui.nvim"
    "nvim-nio"
    "nvim-web-devicons"
    "plenary.nvim"
    "schemastore.nvim"
  ];

  optNames =
    if profile == "vscode"
    then vscodePlugins
    else lib.subtractLists terminalStartPlugins (lib.attrNames plugins);
  startNames = lib.optionals (profile == "terminal") terminalStartPlugins;

  # Only the runtime tree; tests and docs stay out of the deployed config.
  runtimeConfig = lib.fileset.toSource {
    root = ./config;
    fileset = lib.fileset.unions [./config/lua ./config/lsp];
  };

  lazygitNvimEdit = pkgs.callPackage ../../../packages/lazygit-nvim-edit.nix {};
in {
  assertions = [
    {
      assertion = lib.elem profile ["terminal" "vscode"];
      message = "users/maxpw/neovim: unknown profile ${profile}";
    }
  ];

  imports = [./options.nix];

  package = pkgs.neovim-unwrapped;
  wrapRc = true;
  # Keep ~/.config/nvim and stdpath("data")/site off the runtimepath so the old
  # chezmoi-deployed tree and lazy.nvim-era parsers can never be loaded.
  impureRtp = false;
  withRuby = false;
  withPython3 = false;
  withNodeJs = false;
  withPerl = false;

  env = lib.optionalAttrs (appName != null) {NVIM_APPNAME = appName;};

  plugins.lz-n.enable = true;

  extraPlugins =
    pluginSet.treesitterRuntime
    ++ map (name: plugins.${name}) startNames
    ++ map (name: {
      plugin = plugins.${name};
      optional = true;
    })
    optNames;

  extraPackages = lib.optionals (profile == "terminal") (import ./tooling.nix toolPkgs);

  globals =
    {
      maxpw_nvim_profile = profile;
      maxpw_nvim_config_dir = "${runtimeConfig}";
      maxpw_treesitter_parsers = pluginSet.treesitterParsers;
    }
    // lib.optionalAttrs (profile == "terminal") {
      maxpw_lazygit_nvim_edit = lib.getExe lazygitNvimEdit;
    };

  extraConfigLuaPre = ''
    -- impureRtp = false still leaves XDG config/data "site" directories on both
    -- paths, so a stale ~/.local/share/nvim/site/{parser,plugin,pack} from the
    -- lazy.nvim era would load. Everything this editor needs is in the store,
    -- except the vscode-neovim extension runtime: the extension prepends it via
    -- --cmd before init, and its `vscode.*` modules are required later.
    local vscode_runtime = vim.g.vscode and vim.g.vscode_neovim_runtime
    for _, option in ipairs({ "runtimepath", "packpath" }) do
      local pure = vim.tbl_filter(function(dir)
        return vim.startswith(dir, "/nix/store/") or dir == vscode_runtime
      end, vim.split(vim.o[option], ",", { plain = true }))
      vim.o[option] = table.concat(pure, ",")
    end

    -- Same position the chezmoi init.lua gave its config directory: first, so
    -- lsp/*.lua and lua/ shadow plugin-provided files of the same name.
    vim.opt.rtp:prepend("${runtimeConfig}")
  '';

  extraConfigLua = ''
    require("config")
  '';
}
