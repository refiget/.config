return {
  {
    "folke/flash.nvim",
    -- Keep default s/S behavior, disable remote r/R.
    keys = {
      { "r", mode = "o", false },
      { "R", mode = { "o", "x" }, false },
    },
    opts = {
      modes = {
        char = {
          keys = { "f", "F" },
        },
      },
    },
  },
}
