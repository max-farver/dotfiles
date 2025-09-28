return {
	'nvim-mini/mini.colors',
	version = '*',
	enabled = false,
	config = function()
		local MiniColors = require('mini.colors')
		MiniColors.setup()
		local palette = {
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
				-- Tree-sitter text-objects highlight groups
				TSTextObject = { fg = '#f1fa8c' },
				TSDefinition = { fg = '#8be9fd' },
				TSEnhancedTextObject = { fg = '#50fa7b' },
				-- Markdown highlighting
				Markdown = { fg = '#f8f8f2' },
				MarkdownCode = { fg = '#50fa7b' },
				MarkdownCodeDelimiter = { fg = '#ff79c6' },
				MarkdownHeader = { fg = '#bd93f9', bold = true },
				MarkdownH1 = { fg = '#bd93f9', bold = true },
				MarkdownH2 = { fg = '#bd93f9', bold = true },
				MarkdownH3 = { fg = '#bd93f9', bold = true },
				MarkdownBold = { bold = true },
				MarkdownItalic = { italic = true },
				MarkdownListMarker = { fg = '#ffb86c' },
				MarkdownLink = { fg = '#8be9fd' },
				MarkdownUrl = { fg = '#8be9fd', underline = true },
				MarkdownBlockquote = { fg = '#6272a4', italic = true },
				-- Markdown markup (tree-sitter markup) mappings
				Markup = { fg = '#f8f8f2' },
				MarkupBold = { bold = true },
				MarkupItalic = { italic = true },
				MarkupCode = { fg = '#50fa7b' },
				MarkupHeading = { fg = '#bd93f9', bold = true },
				MarkupList = { fg = '#ffb86c' },
				MarkupLink = { fg = '#8be9fd' },
				MarkupURL = { fg = '#8be9fd', underline = true },
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
		}
		local cs = MiniColors.as_colorscheme(palette)
		cs:apply()

		-- Common Tree-sitter capture highlight links
		vim.cmd("highlight! link @lsp Function")
		vim.cmd("highlight! link @type Type")
		vim.cmd("highlight! link @type.builtin Type")
		vim.cmd("highlight! link @variable Identifier")
		vim.cmd("highlight! link @function Function")
		vim.cmd("highlight! link @property Identifier")
		vim.cmd("highlight! link @parameter Identifier")
		vim.cmd("highlight! link @method Function")
		vim.cmd("highlight! link @namespace Identifier")
		vim.cmd("highlight! link @class Type")
		vim.cmd("highlight! link @struct Type")
		vim.cmd("highlight! link @enum Type")

		-- Markdown markup highlights (if using tree-sitter-markdown or similar)
		vim.cmd("highlight! link Markdown Markup")
		vim.cmd("highlight! link MarkdownBold MarkdownBold")
		vim.cmd("highlight! link MarkdownItalic MarkdownItalic")
		vim.cmd("highlight! link MarkdownCode MarkdownCode")
		vim.cmd("highlight! link MarkdownHeading MarkdownHeader")
		vim.cmd("highlight! link MarkdownListMarker MarkdownListMarker")
		vim.cmd("highlight! link MarkdownLink MarkdownLink")
		vim.cmd("highlight! link MarkdownUrl MarkdownUrl")
		vim.cmd("highlight! link MarkdownBlockquote MarkdownBlockquote")

		vim.api.nvim_set_hl(0, 'MiniPickMatchCurrent', { bg = '#44475a' })
		vim.cmd('highlight! link MiniPickMatchMarked Visual')
	end

}
