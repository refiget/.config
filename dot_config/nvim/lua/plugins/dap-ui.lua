return {
  {
    "rcarriga/nvim-dap-ui",
    opts = function(_, opts)
      opts = opts or {}
      -- Show REPL + commonly needed debug panes.
      opts.layouts = {
        {
          position = "left",
          size = 40,
          elements = {
            { id = "scopes", size = 0.7 },
            { id = "breakpoints", size = 0.3 },
          },
        },
        {
          position = "bottom",
          size = 12,
          elements = {
            { id = "repl", size = 1.0 },
          },
        },
      }
      return opts
    end,
    config = function(_, opts)
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup(opts)

      -- Disable auto-close behavior from distro defaults.
      dap.listeners.before.event_terminated["dapui_config"] = nil
      dap.listeners.before.event_exited["dapui_config"] = nil

      -- Keep auto-open (unless explicitly suppressed for one run).
      dap.listeners.after.event_initialized["dapui_config"] = function()
        if vim.g._dapui_suppress_next_open then
          vim.g._dapui_suppress_next_open = false
          return
        end
        dapui.open()
      end
    end,
  },
}
