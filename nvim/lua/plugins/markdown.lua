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

	-- {
	-- 	"MeanderingProgrammer/render-markdown.nvim",
	-- 	opts = {
	-- 		code = {
	-- 			sign = false,
	-- 			width = "block",
	-- 			right_pad = 1,
	-- 		},
	-- 		heading = {
	-- 			sign = false,
	-- 			icons = {},
	-- 		},
	-- 		checkbox = {
	-- 			enabled = false,
	-- 		},
	-- 	},
	-- 	ft = { "markdown", "norg", "rmd", "org", "codecompanion" },
	-- 	config = function(_, opts)
	-- 		require("render-markdown").setup(opts)
	-- 		Snacks.toggle({
	-- 			name = "Render Markdown",
	-- 			get = function()
	-- 				return require("render-markdown.state").enabled
	-- 			end,
	-- 			set = function(enabled)
	-- 				local m = require("render-markdown")
	-- 				if enabled then
	-- 					m.enable()
	-- 				else
	-- 					m.disable()
	-- 				end
	-- 			end,
	-- 		}):map("<leader>um")
	-- 	end,
	-- },

	{
		"OXY2DEV/markview.nvim",
		lazy = true,
		ft = { "markdown" },
		-- init = function(args)
		-- 			require("markview").actions.set_query(args.buf)
		-- 		end,
		-- 		once = true,
		-- 	})
		-- end,
		config = function()
			local presets = require("markview.presets")

			require("markview").setup({
				preview = {
					-- hybrid_enabled = true,
					modes = { "n", "no", "c", "i" },
					hybrid_modes = { "i" },
					-- raw_previews = { markdown = { "code_blocks" } },
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
