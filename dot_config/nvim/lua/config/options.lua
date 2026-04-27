-- Options are automatically loaded before lazy.nvim startup
-- Add any additional options here

-- jdtls from Mason requires Java 21; set only for Neovim process
vim.env.JAVA_HOME = "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
vim.env.PATH = vim.env.JAVA_HOME .. "/bin:" .. (vim.env.PATH or "")

-- Keep delete/change/yank in Neovim registers unless explicitly using "+
vim.opt.clipboard = ""

-- Faster CursorHold for diagnostic hover
vim.o.updatetime = 300
vim.opt.numberwidth = 4

-- Enable line wrapping
vim.opt.wrap = true
vim.opt.linebreak = true -- Break at word boundaries
vim.opt.breakindent = true -- Keep indentation when wrapping

-- Keep 5 context lines above/below cursor while scrolling
vim.opt.scrolloff = 5
