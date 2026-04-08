vim.g.mapleader = ' '
vim.g.maplocalleader = ','

local opt = vim.opt

-- Confirm before closing unsaved buffers
opt.confirm = true

opt.autowrite = true
opt.breakindent = true
-- Do not auto-insert completion items. First item is highlighted, but only
-- inserted when you confirm (e.g., with <Tab>).
opt.completeopt = { "menu", "menuone", "noinsert" }
opt.conceallevel = 2
opt.cursorline = true
opt.clipboard = "unnamedplus"
-- Hide the command line when not in use to avoid an extra empty row
-- Requires Neovim >= 0.9
opt.cmdheight = 0
-- Show command feedback in the statusline instead of taking cmdline space
opt.showcmdloc = 'statusline'
-- Fold configuration (grouped together)
opt.fillchars = { eob = " ", fold = " ", foldopen = "-", foldclose = "+", foldsep = " " }
opt.foldenable = true
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldmethod = "expr"
opt.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
opt.foldtext = ""
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("user_formatoptions", { clear = true }),
	pattern = "*",
	callback = function()
		vim.opt_local.formatoptions:remove({ "o", "r" })
	end,
})
vim.b.disable_autoformat = false
vim.g.disable_autoformat = false
opt.grepformat = "%f:%l:%c:%m"
opt.grepprg = "rg --vimgrep"
opt.inccommand = "nosplit"
opt.incsearch = true
opt.linebreak = true
opt.smoothscroll = true
opt.laststatus = 3
opt.list = false
opt.pumborder = "rounded"
opt.pumblend = 10
opt.pumheight = 16
opt.scrolloff = 8
opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" }
opt.shortmess:append({ W = true, I = true, c = true })
-- Reduce message noise when cmdheight=0 so it doesn't reserve space
opt.shortmess:append({ F = true })
opt.sidescrolloff = 8
opt.splitkeep = "screen"
opt.wildmode = "longest:full,full"
-- Use popupmenu for command-line completion to avoid using the cmdline area
opt.wildoptions = "pum"
-- Command-line history: size and persistence (ShaDa)
opt.history = 2000
opt.shada = "!,'1000,<50,s100,:1000,/1000"
opt.diffopt:append({ "indent-heuristic", "inline:char" })
opt.virtualedit = "block"
opt.winminwidth = 5
opt.ruler = false
opt.tabstop = 4
opt.shiftwidth = 4
opt.relativenumber = true

opt.autoread = true

-- vim.highlight.priorities.semantic_tokens = 95

vim.g.copilot_workspace_folders = { vim.fn.getcwd() }

-- Update copilot workspace when changing directories
vim.api.nvim_create_autocmd('DirChanged', {
	callback = function()
		vim.g.copilot_workspace_folders = { vim.fn.getcwd() }
	end,
})

-- Markdown indentation behavior fix
vim.g.markdown_recommended_style = 0

-- Treesitter foldexpr is already set in the fold configuration section above
