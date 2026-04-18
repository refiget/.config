return {
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      require("lsp.java").setup_jdtls(opts)
    end,
  },
}
