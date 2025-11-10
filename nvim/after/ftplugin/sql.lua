local add = MiniDeps.add
local project = _G.Config.project
local helpers = _G.Config.ftplugin_helpers

local function ensure_sql_plugins()
	if vim.b._sql_ftplugin_plugins_loaded then
		return
	end
	vim.b._sql_ftplugin_plugins_loaded = true

	add("tpope/vim-dadbod")
	add({
		source = "kristijanhusak/vim-dadbod-completion",
		depends = "tpope/vim-dadbod",
	})
	add({
		source = "kristijanhusak/vim-dadbod-ui",
		depends = "tpope/vim-dadbod",
	})

	local data_path = vim.fn.stdpath("data")
	vim.g.db_ui_auto_execute_table_helpers = 1
	vim.g.db_ui_save_location = data_path .. "/dadbod_ui"
	vim.g.db_ui_show_database_icon = true
	vim.g.db_ui_tmp_query_location = data_path .. "/dadbod_ui/tmp"
	vim.g.db_ui_use_nerd_fonts = true
	vim.g.db_ui_use_nvim_notify = true
	vim.g.db_ui_execute_on_save = false
end

local function setup()
	ensure_sql_plugins()

	helpers.setup_lsp("postgres_lsp")

	vim.b.formatters = project.get_formatters("sql") or { "sqlfluff" }
end

setup()
