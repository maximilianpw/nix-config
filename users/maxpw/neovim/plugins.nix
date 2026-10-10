# Every Neovim plugin, keyed by the name lz.n loads it by (its pack directory).
#
# Pure-Lua plugins are built from the exact commits in plugin-pins.json (carried
# over from the former lazy-lock.json; refresh with scripts/nvim-plugin-pins.sh).
# Plugins with native code or generated grammars come from the pinned nixpkgs
# package set instead, so Nix builds their libraries and parsers as one
# compatible set rather than mixing a locked Lua revision with a different
# native build.
{
  lib,
  pkgs,
}: let
  inherit (pkgs) vimPlugins;

  pins = lib.importJSON ./plugin-pins.json;

  # Plugin dependency edges are expressed in Lua (packadd / trigger_load), not
  # in nixpkgs metadata. Dropping them keeps nixpkgs from adding a second copy
  # of a library under the same pack name. `//` leaves the derivation intact.
  withoutDeps = plugin: plugin // {dependencies = [];};

  pinned =
    lib.mapAttrs (
      name: pin:
        pkgs.vimUtils.buildVimPlugin {
          pname = name;
          version = "0-unstable-${builtins.substring 0 12 pin.rev}";
          src = pkgs.fetchFromGitHub {
            inherit (pin) owner repo rev hash;
          };
          # Behavior is covered by users/maxpw/neovim/tests; nixpkgs' module
          # require checks assume its own dependency graph.
          doCheck = false;
          meta.homepage = "https://github.com/${pin.owner}/${pin.repo}";
        }
    )
    pins;

  treesitterParsers = [
    "bash"
    "c"
    "cpp"
    "css"
    "diff"
    "go"
    "html"
    "javascript"
    "json"
    "lua"
    "luadoc"
    "markdown"
    "markdown_inline"
    "python"
    "query"
    "rust"
    "toml"
    "tsx"
    "typescript"
    "vim"
    "vimdoc"
    "yaml"
    "zig"
  ];

  treesitterWithGrammars = vimPlugins.nvim-treesitter.withPlugins (
    grammars: map (name: grammars.${name}) treesitterParsers
  );

  # Grammars plus their query plugins, including inherited query languages such
  # as ecma/jsx for javascript and tsx.
  treesitterRuntime = let
    closure = plugins:
      lib.unique (lib.concatMap (p: [p] ++ closure (p.dependencies or [])) plugins);
  in
    map withoutDeps (closure treesitterWithGrammars.dependencies);
in {
  inherit treesitterParsers treesitterRuntime;

  plugins =
    pinned
    // {
      # Native Rust matcher / library built by nixpkgs.
      "blink.cmp" = withoutDeps vimPlugins.blink-cmp;
      "codediff.nvim" = withoutDeps vimPlugins.codediff-nvim;
      "fff.nvim" = withoutDeps vimPlugins.fff-nvim;
      # Queries must match the nixpkgs-built grammars; textobjects tracks the
      # same main-branch API.
      "nvim-treesitter" = withoutDeps vimPlugins.nvim-treesitter;
      "nvim-treesitter-textobjects" = withoutDeps vimPlugins.nvim-treesitter-textobjects;
    };
}
