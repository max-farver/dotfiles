-- ============================================================================
-- PHASE 1: Plugin Declarations (evaluated at startup by lazy.nvim)
-- ============================================================================
local M = {}
local project = require("util.project")

M.plugins = {
	{
		"obsidian-nvim/obsidian.nvim",
		enabled = require("util.os").is_linux,
		version = "*",
		event = {
			"BufReadPre " .. vim.fn.expand "~" .. "/Documents/obsidian/**/*.md",
			"BufNewFile  " .. vim.fn.expand "~" .. "/Documents/obsidian/**/*.md",
		},
		opts = project.merge_plugin_opts('obsidian-nvim/obsidian.nvim', {
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
		}),
	},

	{
		"iamcco/markdown-preview.nvim",
		cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
		ft = { "markdown" },
		build = {
			":call mkdp#util#install()",
			":Lazy build markdown-preview.nvim",
		},
	},

	-- {
	-- 	"yousefhadder/markdown-plus.nvim",
	-- 	config = function()
	-- 		require("markdown-plus").setup({
	-- 			-- Configuration options (all optional)
	-- 			enabled = true,
	-- 			features = {
	-- 				list_management = true, -- List management features
	-- 				text_formatting = true, -- Text formatting features
	-- 				headers_toc = true, -- Headers + TOC features
	-- 				links = true, -- Link management features
	-- 				quotes = true, -- Blockquote toggling feature
	-- 				code_block = true, -- Code block conversion feature
	-- 				table = true, -- Table support features
	-- 			},
	-- 			keymaps = {
	-- 				enabled = true, -- Enable default keymaps (<Plug> available for custom)
	-- 			},
	-- 			toc = { -- TOC window configuration
	-- 				initial_depth = 2,
	-- 			},
	-- 			table = { -- Table sub-configuration
	-- 				auto_format = true,
	-- 				default_alignment = "left",
	-- 				keymaps = { enabled = true, prefix = "<leader>t" },
	-- 			},
	-- 			filetypes = { "markdown" },
	-- 		})
	-- 	end,
	-- },

	{
		"OXY2DEV/markview.nvim",
		lazy = false,
		init = function()
			vim.g.markview_lazy_loaded = true;
		end,
		opts = function()
			local presets = require("markview.presets")
			return project.merge_plugin_opts('OXY2DEV/markview.nvim', {
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
			})
		end,
	},
}

-- ============================================================================
-- PHASE 2: Runtime Configuration (runs when markdown buffer loads)
-- ============================================================================
local function setup()
	-- Enable spelling and wrap for window
	vim.cmd('setlocal nospell wrap')

	-- Fold with tree-sitter
	vim.cmd('setlocal foldmethod=expr foldexpr=v:lua.vim.treesitter.foldexpr()')

	-- Set markdown-specific surrounding in 'mini.surround'
	vim.b.minisurround_config = {
		custom_surroundings = {
			-- Markdown link. Common usage:
			-- `saiwL` + [type/paste link] + <CR> - add link
			-- `sdL` - delete link
			-- `srLL` + [type/paste link] + <CR> - replace link
			L = {
				input = { '%[().-()%]%(.-%)' },
				output = function()
					local link = require('mini.surround').user_input('Link: ')
					return { left = '[', right = '](' .. link .. ')' }
				end,
			},
		},
	}

	-- LSP Configuration
	local helpers = require("util.ftplugin_helpers")
	helpers.setup_lsp("marksman")

	-- Formatters
	vim.b.formatters = project.get_formatters('markdown') or { 'prettier', 'markdownlint-cli2', 'markdown-toc' }
end

-- Execute setup when buffer loads
setup()

-- Export for lazy.nvim to read at startup
return M
