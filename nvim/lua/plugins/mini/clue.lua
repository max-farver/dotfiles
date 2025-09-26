return {
	'nvim-mini/mini.clue',
	version = '*',
	event = 'VeryLazy',
	opts = function()
		local clue = require('mini.clue')

		-- Define triggers first
		local triggers = {
			-- Leader
			{ mode = 'n', keys = '<Leader>' },
			{ mode = 'x', keys = '<Leader>' },
			{ mode = 'o', keys = '<Leader>' },
			-- Brackets
			{ mode = 'n', keys = '[' },
			{ mode = 'n', keys = ']' },
			-- g/z prefixes
			{ mode = 'n', keys = 'g' },
			{ mode = 'x', keys = 'g' },
			{ mode = 'n', keys = 'z' },
			{ mode = 'x', keys = 'z' },
			-- Window commands
			{ mode = 'n', keys = '<C-w>' },
			-- Insert completion
			{ mode = 'i', keys = '<C-x>' },
			-- v/y prefixes
			{ mode = 'n', keys = 'y' },
			{ mode = 'n', keys = 'v' },
		}

		-- Build clues list
		local clues = {
			-- Builtins
			clue.gen_clues.builtin_completion(),
			clue.gen_clues.marks(),
			clue.gen_clues.registers(),
			clue.gen_clues.windows(),
			clue.gen_clues.z(),
			clue.gen_clues.g(),
			-- Leader group labels
			{ mode = 'n', keys = '<Leader>f',  desc = 'Find' },
			{ mode = 'x', keys = '<Leader>f',  desc = 'Find' },
			{ mode = 'n', keys = '<Leader>g',  desc = 'Git' },
			{ mode = 'n', keys = '<Leader>u',  desc = 'UI' },
			{ mode = 'n', keys = '<Leader>d',  desc = 'Debug' },
			{ mode = 'n', keys = '<Leader>t',  desc = 'Terminal/Test' },
			{ mode = 'n', keys = '<Leader>w',  desc = 'Windows' },
			{ mode = 'n', keys = '<Leader>b',  desc = 'Buffers' },
			{ mode = 'n', keys = '<Leader>c',  desc = 'Code' },
			{ mode = 'n', keys = '<Leader>cl', desc = 'LSP' },
			{ mode = 'n', keys = '<Leader>o',  desc = 'Overseer/Other' },
		}

		-- Heuristic window width based on longest description
		local max_desc = 0
		for _, c in ipairs(clues) do
			if type(c) == 'table' and type(c.desc) == 'string' then
				if #c.desc > max_desc then max_desc = #c.desc end
			end
		end
		-- Add space for keys column and padding (~22 chars)
		local cols = vim.o.columns
		local computed = max_desc + 22
		local width = math.max(40, math.min(math.floor(cols * 0.6), math.min(100, computed)))

		return {
			window = {
				delay = 100,
				config = { width = width, border = 'rounded' },
			},
			triggers = triggers,
			clues = clues,
		}
	end,
	config = function(_, opts)
		-- ensure key timeout is enabled so clue can trigger
		vim.o.timeout = true
		vim.o.timeoutlen = vim.o.timeoutlen > 0 and vim.o.timeoutlen or 300
		require('mini.clue').setup(opts)
	end,
}
