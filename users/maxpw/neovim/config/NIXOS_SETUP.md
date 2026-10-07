# Neovim Tooling Setup

Nixvim (`users/maxpw/neovim`) packages this config together with every plugin, the
native blink.cmp and fff.nvim libraries, and the Treesitter parsers; nothing is
downloaded or compiled at runtime except Supermaven's engine. Editor-only tools
(language servers, debuggers, linters) come from `users/maxpw/neovim/tooling.nix`;
formatters shared with the shell come from `modules/packages/dev-tools.nix`.
Project environments may add more.

## Neovim Versions And Validation

The Nix configuration currently selects Neovim 0.12.5 through its locked
nixpkgs-unstable input. As of 2026-09-05, 0.13 is a development prerelease, not
a stable release. Testing nightly here does not change the host package.

Run `nix build .#checks.<system>.nvim-candidate` from nix-config. It runs
`users/maxpw/neovim/tests` against the packaged editors in disposable XDG
directories and checks startup, JSX/TSX highlighting, big-file ordering,
formatter discovery, textobject motions, and breakpoint persistence. It does not
validate every external language server, authenticated AI service, or every
interactive workflow. Plugin revisions live in `users/maxpw/neovim/plugin-pins.json`;
move them with `scripts/nvim-plugin-pins.sh`.

Treesitter textobject mappings use the standalone main-branch API. Insert-mode
`<Tab>` accepts a visible Blink completion, advances snippets, accepts visible
Supermaven ghost text, or falls back to indentation, in that order. `<C-l>`
accepts Supermaven directly. The `<leader>db` and `<leader>dB` mappings save
breakpoints and restore them even when DAP loads after the file was opened.

Before switching to 0.13, review `:help news`: `Q` adds native multicursors,
while the default `<C-l>` clears them. This config maps normal-mode `<C-l>` to
tmux navigation, so multicursor clearing needs a separate mapping if used.
`vim.hl.on_yank()` is deprecated in favor of `vim.hl.hl_op()`, and native
file watching improves `autoread`. Keep compatibility with stable until the
host package is deliberately switched; there is no need to replace lz.n,
Blink, or the LSP configuration merely to try 0.13.

## Tools

Add editor-only tools to `users/maxpw/neovim/tooling.nix` and shell-visible
formatters or linters to `modules/packages/dev-tools.nix`.

The companion Nix configuration supplies `lldb` (including `lldb-dap`) for Rust debugging.
Add optional tools only when needed: `vale` for prose and a JavaScript debug adapter on PATH.
The removed go.nvim installer hook does not provision tools; install Go helpers through Nix
or the project before using their commands.

## Enabled LSP Servers

`lua/plugins/lsp/init.lua` enables these native Neovim LSP configs:

- `astro`
- `bashls`
- `biome`
- `cssls`
- `dockerls`
- `eslint`
- `gopls`
- `html`
- `jsonls`
- `lua_ls`
- `nil_ls`
- `nushell`
- `tailwindcss`
- `taplo`
- `yamlls`
- `zls`

Rust is handled by `rustaceanvim`, not the shared LSP server list. TypeScript is handled by `typescript-tools`, which needs the `typescript` package's `tsserver`. The `nushell` server is `nu --lsp`, provided by the nushell package itself.

Server-specific settings live in `lsp/*.lua`.

## Formatters And Linters

Formatting is configured in `lua/plugins/style/autoformat.lua` through conform.nvim. Go formatting is owned by conform.nvim with `goimports` and `gofmt`.

Save formatting and both `<leader>cf` / `<leader>cF` use the same selection policy.
For web filetypes, a project Biome config selects Biome only for its configured
supported filetypes; otherwise a project Prettier config selects Prettier.
Without a matching formatter config, no web formatter or arbitrary LSP fallback runs.
ESLint-only projects use explicit ESLint code actions for fixes, not LSP formatting.
TypeScript Prettier/ESLint config filenames are recognized, but the project must
supply compatible tool versions and any required Node support or loader (such as
ESLint's `jiti` dependency). Config discovery alone does not install these prerequisites.

Linting is configured in `lua/plugins/style/lint.lua` through nvim-lint. ESLint diagnostics come from the ESLint LSP, not nvim-lint:

- `oxlint` runs when `oxlintrc.json` or `.oxlintrc.json` exists.
- Heavy linters run on save only.

## Debugging

DAP setup is split under `lua/config/dap/`:

- `ui.lua` configures dap-ui, signs, listeners, and virtual text.
- `js.lua` configures JavaScript and TypeScript debug adapters.
- `languages.lua` configures Go and Rust adapters.
- `breakpoints.lua` configures persistent breakpoints.

JavaScript debugging uses `js-debug` (nixpkgs' `vscode-js-debug`) or `js-debug-adapter` from PATH. If neither is available, Neovim shows a warning when DAP loads.

Rust debugging prompts for the built executable rather than guessing from Cargo.toml;
argument input uses nvim-dap's quoted-argument parser. Build the desired target first.
Neotest's project key selects the nearest package/Go/Cargo/VCS root. Jest and Mocha
derive their working directory from the test path, and adapters discover their own
commands instead of forcing every package through `npm test`.

## Large Files And VS Code

The shared 100/150/200 KiB tiers are classified before plugin loading and updated
as buffers grow or shrink, including unsaved buffers. Window options, syntax,
Treesitter indentation/highlighting, and buffer semantic-token policy are restored
when the relevant restriction no longer applies. Thresholds remain unchanged.
Snacks loads early for its dashboard; its independent quickfile highlighter is
disabled so it cannot bypass the shared Treesitter guard. Other Snacks features
and FFF remain available.

Inside vscode-neovim, the separate `nvim-vscode` package ships only mini editing
utilities, Flash, Treesitter/textobjects, and ts-comments. VS Code owns completion,
LSP, formatting, navigation between editor groups, and UI.

## Troubleshooting

Use these commands inside Neovim:

```vim
:checkhealth
:LspInfo
:ConformInfo
:LintNow
```

Use shell checks to verify tools are on PATH:

```bash
which astro-ls
which gopls
which lua-language-server
which prettierd
which stylua
which vscode-eslint-language-server
```
