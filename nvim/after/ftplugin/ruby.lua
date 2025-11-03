-- ============================================================================
-- PHASE 1: Plugin Declarations (evaluated at startup by lazy.nvim)
-- ============================================================================
local M = {}

M.plugins = {
	{
		"tpope/vim-rails",
		ft = "ruby",
		dependencies = {
			"tpope/vim-bundler",
			"tpope/vim-dispatch",
		},
	},
}

-- ============================================================================
-- PHASE 2: Runtime Configuration (runs when ruby buffer loads)
-- ============================================================================
local function setup()
	local helpers = require("util.ftplugin_helpers")
	local project = require("util.project")

	-- LSP Configuration (ruby-lsp via asdf)
	helpers.setup_lsp("ruby_lsp", {
		cmd = { vim.fn.expand("~/.asdf/shims/ruby-lsp") },
	})

	-- Formatters & Linters (ruby_lsp handles formatting)
	local formatters = project.get_formatters('ruby')
	if formatters then
		vim.b.formatters = formatters
	end

	local linters = project.get_linters('ruby')
	if linters then
		vim.b.linters = linters
	end
end

-- Execute setup when buffer loads
setup()

-- Export for lazy.nvim to read at startup
return M
