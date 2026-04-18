return {
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      opts = opts or {}
      local old_delay = opts.delay
      opts.delay = function(ctx)
        -- Don't popup on comma-prefix (localleader) to avoid visual noise.
        if ctx and type(ctx.keys) == "string" and ctx.keys:sub(1, 1) == "," then
          return 100000
        end
        if type(old_delay) == "function" then
          return old_delay(ctx)
        end
        return old_delay or 200
      end
      return opts
    end,
  },
}
