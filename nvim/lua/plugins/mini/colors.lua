return {
	'nvim-mini/mini.colors',
	version = '*',
	config = function()
		local MiniColors = require('mini.colors')
		MiniColors.setup()
		local cs = MiniColors.as_colorscheme({
			name = 'dracula_mini',
			groups = {
				Normal = { fg = '#f8f8f2', bg = '#282a36' },
				NormalFloat = { fg = '#f8f8f2', bg = '#282a36' },
				CursorLine = { bg = '#44475a' },
				CursorLineNr = { fg = '#ff79c6', bold = true },
				Comment = { fg = '#6272a4', italic = true },
				String = { fg = '#50fa7b' },
				Function = { fg = '#8be9fd' },
				Keyword = { fg = '#ff79c6', bold = true },
				Identifier = { fg = '#f1fa8c' },
				Type = { fg = '#bd93f9' },
				Constant = { fg = '#bd93f9' },
				ErrorMsg = { fg = '#ff5555' },
				WarningMsg = { fg = '#f1fa8c' },
				Visual = { bg = '#44475a' },
				Search = { fg = '#282a36', bg = '#ffb86c' },
				Pmenu = { fg = '#f8f8f2', bg = '#44475a' },
				StatusLine = { fg = '#f8f8f2', bg = '#44475a' },
				TabLineSel = { fg = '#282a36', bg = '#bd93f9', bold = true },
				Todo = { fg = '#282a36', bg = '#bd93f9', bold = true },
			},
			terminal = {
				[0] = '#282a36',
				[1] = '#ff5555',
				[2] = '#50fa7b',
				[3] = '#f1fa8c',
				[4] = '#bd93f9',
				[5] = '#ff79c6',
				[6] = '#8be9fd',
				[7] = '#f8f8f2',
				[8] = '#44475a',
				[9] = '#ff5555',
				[10] = '#50fa7b',
				[11] = '#f1fa8c',
				[12] = '#bd93f9',
				[13] = '#ff79c6',
				[14] = '#8be9fd',
				[15] = '#f8f8f2',
			},
		})
		cs:apply()

		-- Helper to set MiniPick selected background
		vim.api.nvim_set_hl(0, 'MiniPickMatchCurrent', { bg = '#44475a' })
		-- Keep marked matches linked to Visual for consistency
		vim.cmd('highlight! link MiniPickMatchMarked Visual')
	end
}
