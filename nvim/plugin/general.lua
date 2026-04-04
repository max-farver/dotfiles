local add_once = _G.Config.pack_add_once or _G.Config.pack_add
local now, later = _G.Config.now, _G.Config.later
local map = _G.Config.map

now(function()
	add_once({ { src = "https://github.com/christoomey/vim-tmux-navigator" } })

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
	add_once({ { src = "https://github.com/folke/flash.nvim" } })
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

later(function()
	add_once({ { src = "https://github.com/gbprod/yanky.nvim" } })
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

later(function()
	add_once({ { src = "https://github.com/stevearc/overseer.nvim" } })
	require("overseer").setup()
end)

later(function()
	add_once({ { src = "https://github.com/smjonas/inc-rename.nvim" } })
	require("inc_rename").setup()
end)

later(function()
	add_once({
		{ src = "https://github.com/nvim-treesitter/nvim-treesitter", version = 'main' },
	})

	_G.Config.nvim_ts = require("nvim-treesitter")

	add_once({
		{ src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects", version = 'main' },
	})
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
end)
