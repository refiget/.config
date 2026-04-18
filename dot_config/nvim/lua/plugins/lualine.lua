return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      -- remove clock section
      opts.sections = opts.sections or {}
      opts.sections.lualine_z = {}

      -- only change the long statusline bar background (StatusLine), not lualine section colors
      vim.schedule(function()
        local n = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
        if not (n and n.bg) then
          return
        end
        local s = vim.api.nvim_get_hl(0, { name = "StatusLine", link = false })
        local snc = vim.api.nvim_get_hl(0, { name = "StatusLineNC", link = false })
        vim.api.nvim_set_hl(0, "StatusLine", { fg = s and s.fg or nil, bg = n.bg, bold = s and s.bold or false })
        vim.api.nvim_set_hl(0, "StatusLineNC", { fg = snc and snc.fg or nil, bg = n.bg })
      end)
    end,
  },
}
