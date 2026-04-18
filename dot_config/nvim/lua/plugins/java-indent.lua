return {
  {
    "nvim-treesitter/nvim-treesitter",
    init = function()
      local group = vim.api.nvim_create_augroup("JavaIndentSettings", { clear = true })

      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "java",
        callback = function(args)
          local bo = vim.bo[args.buf]
          bo.autoindent = true
          bo.smartindent = true
          bo.cindent = true
          bo.shiftwidth = 4
          bo.tabstop = 4
          bo.softtabstop = 4
          bo.expandtab = true

          -- LazyVim/treesitter may set indentexpr later in the FileType flow.
          -- Clear it on the next tick so Java falls back to classic cindent behavior.
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(args.buf) and vim.bo[args.buf].filetype == "java" then
              vim.bo[args.buf].indentexpr = ""
            end
          end)
        end,
      })
    end,
    opts = function(_, opts)
      opts.indent = opts.indent or {}
      opts.indent.enable = true
      return opts
    end,
  },
}
