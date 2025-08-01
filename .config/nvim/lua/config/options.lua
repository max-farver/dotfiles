-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- copilot options
vim.g.copilot_workspace_folders = { vim.fn.getcwd() }

vim.highlight.priorities.semantic_tokens = 95

vim.opt.autoread = true
