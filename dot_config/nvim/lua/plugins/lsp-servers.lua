return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- Single local entry point for nvim-lspconfig opts.servers mutations.
      local common = require("lsp.common")
      local python = require("lsp.python")
      local java = require("lsp.java")

      opts.servers = vim.tbl_deep_extend("force", opts.servers or {}, common.base_servers())

      python.setup(opts.servers)
      java.setup(opts.servers)
    end,
  },
}
