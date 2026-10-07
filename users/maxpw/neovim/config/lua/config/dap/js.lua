local M = {}

local workspace_root = "${workspaceFolder}"

local function resolve_js_debug_command()
  for _, name in ipairs({ "js-debug", "js-debug-adapter" }) do
    local path = vim.fn.exepath(name)
    if path ~= "" then
      return path
    end
  end
end

local function prompt_debug_port(default_port)
  local value = vim.fn.input("Debug port: ", tostring(default_port or 9229))
  return tonumber(value) or default_port or 9229
end

local function prompt_text(label, default_value)
  local value = vim.fn.input(label, default_value or "")
  return value ~= "" and value or default_value
end

local function prompt_remote_root(default_path)
  local value = prompt_text("Remote root: ", default_path or "/app")
  return value ~= "" and value or default_path or "/app"
end

local function detect_remote_root()
  local cwd = vim.fn.getcwd()

  for _, dockerfile in ipairs({ "Dockerfile", "docker/Dockerfile" }) do
    local path = cwd .. "/" .. dockerfile
    if vim.fn.filereadable(path) == 1 then
      for _, line in ipairs(vim.fn.readfile(path)) do
        local workdir = line:match("^WORKDIR%s+(.+)$")
        if workdir and workdir ~= "" then
          return workdir
        end
      end
    end
  end
end

local function resolve_remote_root(default_path)
  return detect_remote_root() or prompt_remote_root(default_path)
end

local function config_with(base, extra)
  return vim.tbl_deep_extend("force", vim.deepcopy(base), extra or {})
end

function M.setup(dap)
  local js_debug_command = resolve_js_debug_command()
  if js_debug_command then
    for _, adapter in ipairs({ "pwa-node", "pwa-chrome" }) do
      dap.adapters[adapter] = {
        type = "server",
        host = "127.0.0.1",
        port = "${port}",
        executable = {
          command = js_debug_command,
          args = { "${port}", "127.0.0.1" },
        },
      }
    end
  else
    vim.schedule(function()
      vim.notify_once(
        "JavaScript debug adapter not found. Put `js-debug` (vscode-js-debug) on PATH.",
        vim.log.levels.WARN
      )
    end)
  end

  local node_launch_defaults = {
    type = "pwa-node",
    request = "launch",
    cwd = workspace_root,
    sourceMaps = true,
    resolveSourceMapLocations = {
      "${workspaceFolder}/**",
      "!**/node_modules/**",
    },
    outFiles = {
      "${workspaceFolder}/**/*.js",
      "!**/node_modules/**",
    },
    skipFiles = { "<node_internals>/**" },
  }

  local node_attach_defaults = {
    type = "pwa-node",
    request = "attach",
    cwd = workspace_root,
    restart = true,
    localRoot = workspace_root,
    remoteRoot = workspace_root,
    smartStep = true,
    sourceMaps = true,
    outFiles = {
      "${workspaceFolder}/dist/**/*.js",
      "${workspaceFolder}/build/**/*.js",
      "${workspaceFolder}/**/*.js",
      "!**/node_modules/**",
    },
    resolveSourceMapLocations = {
      "${workspaceFolder}/**",
      "!**/node_modules/**",
    },
    skipFiles = { "<node_internals>/**", "**/node_modules/**" },
  }

  local chrome_defaults = {
    type = "pwa-chrome",
    webRoot = workspace_root,
    sourceMaps = true,
    breakOnLoad = true,
    skipFiles = { "<node_internals>/**/*.js" },
  }

  local nest_attach_defaults = config_with(node_attach_defaults, {
    attachExistingChildren = true,
    autoAttachChildProcesses = true,
    pauseForSourceMap = true,
    remoteRoot = function()
      return resolve_remote_root("/app")
    end,
    outFiles = {
      "${workspaceFolder}/dist/**/*.js",
      "${workspaceFolder}/**/*.js",
      "!**/node_modules/**",
    },
    resolveSourceMapLocations = {
      "${workspaceFolder}/dist/**/*.map",
      "${workspaceFolder}/**/*.map",
      "!**/node_modules/**",
    },
    sourceMapPathOverrides = {
      ["webpack:///./~/*"] = "${workspaceFolder}/node_modules/*",
      ["webpack:///./*"] = "${workspaceFolder}/*",
      ["webpack://./*"] = "${workspaceFolder}/*",
      ["webpack:///apps/*"] = "${workspaceFolder}/apps/*",
      ["webpack:///libs/*"] = "${workspaceFolder}/libs/*",
      ["webpack://?:*/apps/*"] = "${workspaceFolder}/apps/*",
      ["webpack://?:*/libs/*"] = "${workspaceFolder}/libs/*",
      ["webpack://?:*/*"] = "${workspaceFolder}/*",
    },
  })

  local function docker_nest_attach(name, port)
    return config_with(nest_attach_defaults, {
      name = name,
      port = port,
      remoteRoot = "/usr/src/app",
    })
  end

  local js_configurations = {
    config_with(node_attach_defaults, {
      name = "Node: Attach by port",
      port = function()
        return prompt_debug_port(9229)
      end,
    }),
    config_with(nest_attach_defaults, {
      name = "Node: Attach NestJS",
      port = function()
        return prompt_debug_port(9229)
      end,
    }),
    config_with(chrome_defaults, {
      request = "launch",
      name = "Chrome: Launch URL",
      url = function()
        return prompt_text("URL: ", "http://localhost:3000")
      end,
    }),
    config_with(chrome_defaults, {
      request = "attach",
      name = "Chrome: Attach (9222)",
      port = 9222,
    }),
    config_with(node_launch_defaults, {
      name = "Node: Launch TSX current file",
      program = "${file}",
      runtimeExecutable = "npx",
      runtimeArgs = { "tsx" },
    }),
    {
      type = "pwa-node",
      request = "launch",
      name = "Node: Launch Jest",
      runtimeExecutable = "node",
      runtimeArgs = {
        "./node_modules/jest/bin/jest.js",
        "--runInBand",
      },
      rootPath = workspace_root,
      cwd = workspace_root,
      console = "integratedTerminal",
      internalConsoleOptions = "neverOpen",
      skipFiles = { "<node_internals>/**", "node_modules/**" },
    },
  }

  local ok_local, local_js = pcall(require, "config.dap.local_js")
  if ok_local and type(local_js) == "table" then
    local local_configurations = local_js.configurations
    if type(local_configurations) == "function" then
      local_configurations = local_configurations({
        config_with = config_with,
        docker_nest_attach = docker_nest_attach,
        nest_attach_defaults = nest_attach_defaults,
        node_attach_defaults = node_attach_defaults,
      })
    end
    if type(local_configurations) == "table" then
      vim.list_extend(js_configurations, local_configurations)
    end
  end

  for _, language in ipairs({ "typescript", "javascript", "typescriptreact", "javascriptreact" }) do
    dap.configurations[language] = vim.deepcopy(js_configurations)
  end
end

return M
