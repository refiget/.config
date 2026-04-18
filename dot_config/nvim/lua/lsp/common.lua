-- Shared LSP config helpers (scaffold only for now).
local M = {}

function M.mason_ensure_installed()
  return {
    "lua-language-server",
    "pyright",
    "typescript-language-server",
    "json-lsp",
    "yaml-language-server",
    "bash-language-server",
    "jdtls",
    "java-test",
    "java-debug-adapter",
  }
end

function M.base_servers()
  return {
    ["*"] = {
      keys = { { "K", false } },
    },
    lua_ls = {},
    pyright = {},
    bashls = {},
    jsonls = {},
    yamlls = {},
    ts_ls = {},
  }
end

return M
