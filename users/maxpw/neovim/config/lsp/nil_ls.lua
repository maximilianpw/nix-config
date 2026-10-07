return {
  cmd = { "nil" },
  filetypes = { "nix" },
  root_markers = { "flake.nix", ".git" },
  settings = {
    ["nil"] = {
      -- Formatting is owned by conform.nvim (alejandra); leave nil as a
      -- pure language server so the two don't compete.
      nix = {
        flake = { autoArchive = true },
      },
    },
  },
}
