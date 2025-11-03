-- ============================================================================
-- PHASE 1: Plugin Declarations (evaluated at startup by lazy.nvim)
-- ============================================================================
local M = {}
local project = require("config.project")

local sql_ft = { "sql", "mysql", "plsql" }

M.plugins = {
	{
		"tpope/vim-dadbod",
		cmd = "DB",
	},
	{
		"kristijanhusak/vim-dadbod-completion",
		dependencies = "tpope/vim-dadbod",
		ft = sql_ft,
	},
	{
		"kristijanhusak/vim-dadbod-ui",
		cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
		dependencies = "tpope/vim-dadbod",
		init = function()
			local data_path = vim.fn.stdpath("data")
			vim.g.db_ui_auto_execute_table_helpers = 1
			vim.g.db_ui_save_location = data_path .. "/dadbod_ui"
			vim.g.db_ui_show_database_icon = true
			vim.g.db_ui_tmp_query_location = data_path .. "/dadbod_ui/tmp"
			vim.g.db_ui_use_nerd_fonts = true
			vim.g.db_ui_use_nvim_notify = true
			vim.g.db_ui_execute_on_save = false
		end,
	},
}

-- ============================================================================
-- PHASE 2: Runtime Configuration (runs when sql buffer loads)
-- ============================================================================
local function setup()
	local helpers = require("config.ftplugin_helpers")

	-- LSP Configuration
	helpers.setup_lsp("postgres_lsp")

	-- Formatters
	vim.b.formatters = project.get_formatters('sql') or { 'sqlfluff' }
end

-- Execute setup when buffer loads
setup()

-- Export for lazy.nvim to read at startup
return M
