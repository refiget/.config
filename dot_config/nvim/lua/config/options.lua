-- Options are automatically loaded before lazy.nvim startup
-- Add any additional options here

-- jdtls from Mason requires Java 21; set only for Neovim process
vim.env.JAVA_HOME = "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
vim.env.PATH = vim.env.JAVA_HOME .. "/bin:" .. (vim.env.PATH or "")

-- Keep delete/change/yank in Neovim registers unless explicitly using "+
vim.opt.clipboard = ""

-- Faster CursorHold for diagnostic hover
vim.o.updatetime = 300
