return {
	{
		"obsidian-nvim/obsidian.nvim",
		version = "*", -- recommended, use latest release instead of latest commit
		event = {
			-- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
			-- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/*.md"
			-- refer to `:h file-pattern` for more examples
			"BufReadPre " .. vim.fn.expand "~" .. "/Documents/obsidian/**/*.md",
			"BufNewFile  " .. vim.fn.expand "~" .. "/Documents/obsidian/**/*.md",
		},
		---@type obsidian.config
		opts = {
			workspaces = {
				{
					name = "personal",
					path = vim.fn.expand "~" .. "/Documents/obsidian/Personal",
				},
			},
			picker = {
				name = "mini.pick",
			},
			legacy_commands = false,
		},
	},

	{
		"OXY2DEV/markview.nvim",
		lazy = true,
		ft = { "markdown" },
		config = function()
			local presets = require("markview.presets")

			require("markview").setup({
				preview = {
					-- hybrid_enabled = true,
					modes = { "n", "no", "c", "i" },
					hybrid_modes = { "i" },
					raw_previews = { markdown = { "code_blocks" } },
				},
				markdown = {
					checkboxes = presets.checkboxes.glow,
					headings = presets.headings.glow,
					horizontal_rules = presets.horizontal_rules.glow,
					tables = presets.tables.glow,
				},
			})
		end,
	},
}
