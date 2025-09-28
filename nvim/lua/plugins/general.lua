local icons = require("config.icons")

return {
	{
		"christoomey/vim-tmux-navigator",
		cmd = {
			"TmuxNavigateLeft",
			"TmuxNavigateDown",
			"TmuxNavigateUp",
			"TmuxNavigateRight",
			"TmuxNavigatePrevious",
			"TmuxNavigatorProcessList",
		},
	},

	{
		"otavioschwanck/arrow.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = {
			show_icons = true,
			leader_key = "M",
			buffer_leader_key = "gm",
		},
	},

	{
		"folke/flash.nvim",
		event = "VeryLazy",
		opts = {},
	},

	{
		"gbprod/yanky.nvim",
		desc = "Better yank/paste",
		event = "BufReadPost",
		opts = {
			highlight = { timer = 150 },
		},
	},

	{
		"stevearc/overseer.nvim",
		cmd = {
			"OverseerRun",
			"OverseerToggle",
			"OverseerTaskAction",
			"OverseerQuickAction",
			"OverseerInfo",
		},
		opts = {},
		-- keymaps defined in config/keymaps.lua
	},

	{
		"ray-x/lsp_signature.nvim",
		event = "InsertEnter",
		version = "0.3.1",
		opts = {},
	},

	{
		"smjonas/inc-rename.nvim",
		cmd = "IncRename",
		opts = {},
	},

	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		opts = function()
			return {
				ensure_installed = {
					"bash",
					"css",
					"dockerfile",
					"git_config",
					"git_rebase",
					"gitattributes",
					"gitcommit",
					"gitignore",
					"go",
					"gomod",
					"gosum",
					"printf",
					"html",
					"hyprlang",
					"javascript",
					"json",
					"json5",
					"jsonc",
					"lua",
					"markdown",
					"markdown_inline",
					"ninja",
					"python",
					"query",
					"regex",
					"rst",
					"sql",
					"terraform",
					"hcl",
					"toml",
					"tsx",
					"typescript",
					"vim",
					"yaml",
				},
				highlight = {
					enable = true,
					additional_vim_regex_highlighting = true,
				},
				indent = { enable = true },
				folds = { enable = true },
				auto_install = true,
			}
		end,
	},

	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "main",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		event = "VeryLazy",
		opts = {
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
		},
	},
}
