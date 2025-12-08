local add = MiniDeps.add
local now, later = MiniDeps.now, MiniDeps.later
local now_if_args = _G.Config.now_if_args
local map = _G.Config.map
local nmap_leader = _G.Config.nmap_leader

now(function()
	add("christoomey/vim-tmux-navigator")

	map('n', '<c-Left>', '<cmd>TmuxNavigateLeft<cr>', { desc = 'Tmux Left' })
	map('n', '<c-h>', '<cmd>TmuxNavigateLeft<cr>', { desc = 'Tmux Left' })
	map('n', '<c-Down>', '<cmd>TmuxNavigateDown<cr>', { desc = 'Tmux Down' })
	map('n', '<c-j>', '<cmd>TmuxNavigateDown<cr>', { desc = 'Tmux Down' })
	map('n', '<c-Up>', '<cmd>TmuxNavigateUp<cr>', { desc = 'Tmux Up' })
	map('n', '<c-k>', '<cmd>TmuxNavigateUp<cr>', { desc = 'Tmux Up' })
	map('n', '<c-Right>', '<cmd>TmuxNavigateRight<cr>', { desc = 'Tmux Right' })
	map('n', '<c-l>', '<cmd>TmuxNavigateRight<cr>', { desc = 'Tmux Right' })
	map('n', '<c-\\>', '<cmd>TmuxNavigatePrevious<cr>', { desc = 'Tmux Previous' })
end)

later(function()
	add("folke/flash.nvim")
	require("flash").setup()


	-- Flash (jump/search)
	map({ 'n', 'x', 'o' }, 's', function()
		local ok, f = pcall(require, 'flash')
		if ok then
			f.jump()
		end
	end, { desc = 'Flash' })
	map({ 'n', 'x', 'o' }, 'S', function()
		local ok, f = pcall(require, 'flash')
		if ok then
			f.treesitter()
		end
	end, { desc = 'Flash Treesitter' })
	map('o', 'r', function()
		local ok, f = pcall(require, 'flash')
		if ok then
			f.remote()
		end
	end, { desc = 'Remote Flash' })
	map({ 'o', 'x' }, 'R', function()
		local ok, f = pcall(require, 'flash')
		if ok then
			f.treesitter_search()
		end
	end, { desc = 'Treesitter Search' })
	map('c', '<c-s>', function()
		local ok, f = pcall(require, 'flash')
		if ok then
			f.toggle()
		end
	end, { desc = 'Toggle Flash Search' })
end)

now(function()
	add("gbprod/yanky.nvim")
	require("yanky").setup({
		highlight = { timer = 150 },
	})

	map({ 'n', 'x' }, 'y', '<Plug>(YankyYank)', { desc = 'Yank Text' })
	map({ 'n', 'x' }, 'p', '<Plug>(YankyPutAfter)', { desc = 'Put After' })
	map({ 'n', 'x' }, 'P', '<Plug>(YankyPutBefore)', { desc = 'Put Before' })
	map({ 'n', 'x' }, 'gp', '<Plug>(YankyGPutAfter)', { desc = 'GPut After' })
	map({ 'n', 'x' }, 'gP', '<Plug>(YankyGPutBefore)', { desc = 'GPut Before' })
	map('n', '[y', '<Plug>(YankyCycleForward)', { desc = 'Yank Cycle Fwd' })
	map('n', ']y', '<Plug>(YankyCycleBackward)', { desc = 'Yank Cycle Back' })
	map('n', ']p', '<Plug>(YankyPutIndentAfterLinewise)', { desc = 'Put Indented After (Linewise)' })
	map('n', '[p', '<Plug>(YankyPutIndentBeforeLinewise)', { desc = 'Put Indented Before (Linewise)' })
	map('n', ']P', '<Plug>(YankyPutIndentAfterLinewise)', { desc = 'Put Indented After (Linewise)' })
	map('n', '[P', '<Plug>(YankyPutIndentBeforeLinewise)', { desc = 'Put Indented Before (Linewise)' })
	map('n', '>p', '<Plug>(YankyPutIndentAfterShiftRight)', { desc = 'Put and Indent Right' })
	map('n', '<p', '<Plug>(YankyPutIndentAfterShiftLeft)', { desc = 'Put and Indent Left' })
	map('n', '>P', '<Plug>(YankyPutIndentBeforeShiftRight)', { desc = 'Put Before and Indent Right' })
	map('n', '<P', '<Plug>(YankyPutIndentBeforeShiftLeft)', { desc = 'Put Before and Indent Left' })
	map('n', '=p', '<Plug>(YankyPutAfterFilter)', { desc = 'Put After Filter' })
	map('n', '=P', '<Plug>(YankyPutBeforeFilter)', { desc = 'Put Before Filter' })
	map({ 'n', 'x' }, '<leader>p', function()
		local ok, pick = pcall(require, 'mini.pick')
		if ok and pick.builtin and pick.builtin.yanky then
			pick.builtin.yanky()
			return
		end
		vim.cmd [[YankyRingHistory]]
	end, { desc = 'Open Yank History' })
end)

now(function()
	add("stevearc/overseer.nvim")
	require("overseer").setup()

	nmap_leader('o', '<nop>', 'Overseer')
	nmap_leader('ot', '<cmd>OverseerToggle<cr>', 'Overseer Toggle')
	nmap_leader('oa', '<cmd>OverseerTaskAction<cr>', 'Overseer Task Action')
	nmap_leader('or', '<cmd>OverseerRun<cr>', 'Overseer Run')
end)

later(function()
	add({
		source = "ray-x/lsp_signature.nvim",
		checkout = "0.3.1",
	})
	require("lsp_signature").setup()
end)

now(function()
	add("smjonas/inc-rename.nvim")
	require("inc_rename").setup()
end)



later(function()
	add({
		source = "OXY2DEV/markview.nvim",
	})
	local presets = require("markview.presets")
	local opts = {
		preview = {
			modes = { "n", "no" },
			raw_previews = { markdown = { "code_blocks" } },
		},
		markdown = {
			checkboxes = presets.checkboxes.glow,
			headings = presets.headings.glow,
			horizontal_rules = presets.horizontal_rules.glow,
			tables = presets.tables.glow,
		},
	}
	require("markview").setup(opts)
	vim.g.markview_lazy_loaded = true
end)

now(function()
	add({
		source = "nvim-treesitter/nvim-treesitter",
		checkout = 'main',
		-- Update tree-sitter parser after plugin is updated
		hooks = { post_checkout = function() vim.cmd('TSUpdate') end },
	})

	require("nvim-treesitter").setup()
	add({
		source = "nvim-treesitter/nvim-treesitter-textobjects",
		checkout = 'main',
		hooks = {
			post_checkout = function()
				require("nvim-treesitter-textobjects").setup({
					select = {
						enable = true,
						lookahead = true,
						keymaps = {
							["af"] = "@function.outer",
							["if"] = "@function.inner",
							["ac"] = "@class.outer",
							["ic"] = "@class.inner",
							["aa"] = "@parameter.outer",
							["ia"] = "@parameter.inner",
							["al"] = "@loop.outer",
							["il"] = "@loop.inner",
							["aC"] = "@conditional.outer",
							["iC"] = "@conditional.inner",
							["ab"] = "@block.outer",
							["ib"] = "@block.inner",
							["as"] = "@statement.outer",
						},
					},
					move = {
						enable = true,
						set_jumps = true,
						goto_next_start = {
							["]f"] = "@function.outer",
							["]c"] = "@class.outer",
						},
						goto_next_end = {
							["]F"] = "@function.outer",
							["]C"] = "@class.outer",
						},
						goto_previous_start = {
							["[f"] = "@function.outer",
							["[c"] = "@class.outer",
						},
						goto_previous_end = {
							["[F"] = "@function.outer",
							["[C"] = "@class.outer",
						},
					},
					swap = {
						enable = true,
						swap_next = {
							["]a"] = "@parameter.inner",
						},
						swap_previous = {
							["[a"] = "@parameter.inner",
						},
					},
				})
			end
		}
	})
	-- Define languages which will have parsers installed and auto enabled
	local languages = {
		-- These are already pre-installed with Neovim. Used as an example.
		'lua',
		'vimdoc',
		'markdown',
		'markdown_inline',
		'go',
		'bash',
		'python'
		-- 'go'
		-- Add here more languages with which you want to use tree-sitter
		-- To see available languages:
		-- - Execute `:=require('nvim-treesitter').get_available()`
		-- - Visit 'SUPPORTED_LANGUAGES.md' file at
		--   https://github.com/nvim-treesitter/nvim-treesitter/blob/main
	}
	local isnt_installed = function(lang)
		return vim.treesitter.language.add(lang) == false
	end
	local to_install = vim.tbl_filter(isnt_installed, languages)
	if #to_install > 0 then
		local ts = require('nvim-treesitter').setup()
		if ts then
			ts.install(to_install)
		end
	end

	-- Enable tree-sitter after opening a file for a target language
	local filetypes = {}
	for _, lang in ipairs(languages) do
		for _, ft in ipairs(vim.treesitter.language.get_filetypes(lang)) do
			table.insert(filetypes, ft)
		end
	end
	local ts_start = function(ev) vim.treesitter.start(ev.buf) end
	_G.Config.new_autocmd('FileType', filetypes, ts_start, 'Start tree-sitter')
end)
