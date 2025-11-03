-- ============================================================================
-- PHASE 1: Plugin Declarations (evaluated at startup by lazy.nvim)
-- ============================================================================
local M = {}
local project = require("util.project")

-- Default venv-selector options
local venv_selector_defaults = {
	options = {
		notify_user_on_venv_activation = true,
		picker = "mini-pick"
	},
}

M.plugins = {
	{
		"linux-cultist/venv-selector.nvim",
		ft = "python",
		cmd = "VenvSelect",
		opts = project.merge_plugin_opts('linux-cultist/venv-selector.nvim', venv_selector_defaults),
	},
	{
		"nvim-neotest/neotest-python",
		ft = "python",
		dependencies = { "nvim-neotest/neotest" },
	},
}

-- ============================================================================
-- PHASE 2: Runtime Configuration (runs when python buffer loads)
-- ============================================================================
local function setup()
	local helpers = require("util.ftplugin_helpers")

	-- LSP Configuration (Pyright + Ruff)
	helpers.setup_lsps({
		pyright = {},
		ruff = {},
	})

	-- Formatters & Linters
	vim.b.formatters = project.get_formatters('python') or { "black" }
	local linters = project.get_linters('python')
	if linters then
		vim.b.linters = linters
	end
end

-- Execute setup when buffer loads
setup()

-- Export for lazy.nvim to read at startup
return M
