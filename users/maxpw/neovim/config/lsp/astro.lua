local ok_util, util = pcall(require, "lspconfig.util")

local function valid_tsdk(path)
  if not path or path == "" then
    return nil
  end

  local sdk = vim.fs.normalize(path)
  if vim.uv.fs_stat(vim.fs.joinpath(sdk, "typescript.js")) then
    return sdk
  end

  return nil
end

local function tsserver_sdk(root_dir)
  if ok_util then
    local local_sdk = util.get_typescript_server_path(root_dir or vim.fn.getcwd())
    local sdk = valid_tsdk(local_sdk)
    if sdk then
      return sdk
    end
  end

  local tsserver = vim.fn.exepath("tsserver")
  if tsserver == "" then
    return nil
  end

  local real_tsserver = vim.uv.fs_realpath(tsserver) or tsserver
  local tsserver_dir = vim.fs.dirname(real_tsserver)
  local candidates = {
    vim.fs.joinpath(tsserver_dir, "../lib/node_modules/typescript/lib"),
    vim.fs.joinpath(tsserver_dir, "../lib"),
  }

  for _, candidate in ipairs(candidates) do
    local sdk = valid_tsdk(candidate)
    if sdk then
      return sdk
    end
  end

  return nil
end

local function ensure_tsdk(config)
  if not (config and config.init_options and config.init_options.typescript) then
    return nil
  end

  if not config.init_options.typescript.tsdk then
    config.init_options.typescript.tsdk = tsserver_sdk(config.root_dir)
  end

  return config.init_options.typescript.tsdk
end

local function typescript_node_path(tsdk)
  local sdk = valid_tsdk(tsdk)
  if not sdk then
    return nil
  end

  local typescript_dir = vim.fs.dirname(sdk)
  if not typescript_dir or vim.fs.basename(typescript_dir) ~= "typescript" then
    return nil
  end

  local node_modules = vim.fs.dirname(typescript_dir)
  if node_modules and vim.fs.basename(node_modules) == "node_modules" then
    return node_modules
  end

  return nil
end

local function prepend_node_path(node_path)
  local existing = vim.env.NODE_PATH
  if existing and existing ~= "" and not existing:find(node_path, 1, true) then
    local path_sep = vim.fn.has("win32") == 1 and ";" or ":"
    return node_path .. path_sep .. existing
  end

  return node_path
end

return {
  _tooling = {
    executables = { "astro-ls", "tsserver" },
  },
  cmd = function(dispatchers, config)
    local cmd = "astro-ls"
    if (config or {}).root_dir then
      local local_cmd = vim.fs.joinpath(config.root_dir, "node_modules/.bin", cmd)
      if vim.fn.executable(local_cmd) == 1 then
        cmd = local_cmd
      end
    end

    local node_path = typescript_node_path(ensure_tsdk(config))
    local extra_spawn_params = {}
    if node_path then
      extra_spawn_params.env = { NODE_PATH = prepend_node_path(node_path) }
    end

    return vim.lsp.rpc.start({ cmd, "--stdio" }, dispatchers, extra_spawn_params)
  end,
  filetypes = { "astro" },
  root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
  init_options = {
    typescript = {},
  },
  before_init = function(_, config)
    ensure_tsdk(config)
  end,
}
