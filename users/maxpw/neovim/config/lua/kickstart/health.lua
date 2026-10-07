local check_version = function()
  local verstr = tostring(vim.version())
  if vim.fn.has("nvim-0.12") == 1 then
    vim.health.ok(string.format("Neovim version is: '%s'", verstr))
  else
    vim.health.error(string.format("Neovim %s is unsupported; this config requires 0.12 or newer", verstr))
  end
end

local check_external_reqs = function()
  for _, exe in ipairs({ "git", "cc", "tree-sitter", "rg", "node" }) do
    local is_executable = vim.fn.executable(exe) == 1
    if is_executable then
      vim.health.ok(string.format("Found executable: '%s'", exe))
    else
      vim.health.warn(string.format("Could not find executable: '%s'", exe))
    end
  end

  return true
end

return {
  check = function()
    vim.health.start("Neovim configuration")

    vim.health.info([[NOTE: Not every warning is a 'must-fix' in `:checkhealth`

  Nix supplies plugins, native libraries (blink.cmp, fff.nvim) and Treesitter
  parsers; Home Manager or project environments supply external tools.
  See NIXOS_SETUP.md and :checkhealth vim.lsp / :ConformInfo for language tooling.
  Fix warnings for the languages and workflows you actually use.]])

    local uv = vim.uv or vim.loop
    vim.health.info("System Information: " .. vim.inspect(uv.os_uname()))

    check_version()
    check_external_reqs()
  end,
}
