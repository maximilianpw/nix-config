# Lazygit's editor hook: reuse the parent Neovim when lazygit runs inside one.
# `nvim` intentionally resolves from PATH so it follows the user's editor.
{writeShellApplication}:
writeShellApplication {
  name = "lazygit-nvim-edit";
  # The script manages its own `set -eu`; keep its POSIX-sh semantics.
  bashOptions = [];
  text = builtins.readFile ./scripts/lazygit-nvim-edit.sh;
}
