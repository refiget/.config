local M = {}

local function referenced_libraries()
  local cs61b_root = vim.fn.expand("~/Desktop/cs61b")
  local lib_dir = cs61b_root .. "/library-sp24"
  if vim.fn.isdirectory(lib_dir) ~= 1 then
    return {}
  end
  return vim.fn.glob(lib_dir .. "/*.jar", false, true)
end

local function apply_java_project_settings(java_settings)
  java_settings.project = {
    sourcePaths = { "src", "tests" },
    outputPath = "out",
    referencedLibraries = referenced_libraries(),
  }
end

local function apply_diag_filter(jdtls)
  local default_publish = vim.lsp.handlers["textDocument/publishDiagnostics"]
  jdtls.handlers = jdtls.handlers or {}
  jdtls.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
    if result and result.diagnostics then
      local filtered = {}
      for _, d in ipairs(result.diagnostics) do
        local msg = d.message or ""
        local ignore = msg:match("is never used")
          or msg:match("is never read")
          or msg:match("The import .- is never used")
          or msg:match("The value of the local variable .- is not used")
          or msg:match("The declared package .- does not match the expected package")
        if not ignore then
          table.insert(filtered, d)
        end
      end
      result.diagnostics = filtered
    end
    return default_publish(err, result, ctx, config)
  end
end

function M.setup(servers)
  local util = require("lspconfig.util")
  servers.jdtls = servers.jdtls or {}
  local jdtls = servers.jdtls

  jdtls.root_dir = util.root_pattern(".cs61b-root", ".git")
  jdtls.settings = jdtls.settings or {}
  jdtls.settings.java = jdtls.settings.java or {}
  apply_java_project_settings(jdtls.settings.java)
  apply_diag_filter(jdtls)

  local mason = vim.fn.stdpath("data") .. "/mason/packages/jdtls"
  local launcher = vim.fn.glob(mason .. "/plugins/org.eclipse.equinox.launcher_*.jar")
  local config_dir = mason .. "/config_mac"

  jdtls.cmd = {
    "/opt/homebrew/opt/openjdk@21/bin/java",
    "-Declipse.application=org.eclipse.jdt.ls.core.id1",
    "-Dosgi.bundles.defaultStartLevel=4",
    "-Declipse.product=org.eclipse.jdt.ls.core.product",
    "-Dlog.protocol=true",
    "-Dlog.level=WARN",
    "-Xmx1g",
    "--add-modules=ALL-SYSTEM",
    "--add-opens", "java.base/java.util=ALL-UNNAMED",
    "--add-opens", "java.base/java.lang=ALL-UNNAMED",
    "-jar", launcher,
    "-configuration", config_dir,
    "-data", vim.fn.stdpath("data") .. "/jdtls-workspace/" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t"),
  }
end

function M.setup_jdtls(opts)
  local util = require("lspconfig.util")
  opts.root_dir = function(path)
    return util.root_pattern(".cs61b-root", ".git")(path)
  end

  opts.settings = opts.settings or {}
  opts.settings.java = opts.settings.java or {}
  apply_java_project_settings(opts.settings.java)
end

return M
