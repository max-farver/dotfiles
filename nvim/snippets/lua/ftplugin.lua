return {
	{
		prefix = 'ftp',
		desc = 'Scaffold after/ftplugin/<ft>.lua',
		body = [[-- ============================================================================
-- PHASE 1: Plugin Declarations (evaluated at startup by lazy.nvim)
-- ============================================================================
local M = {}
local project = require("config.project")
local helpers = require("config.ftplugin_helpers")

M.plugins = {
	-- Add plugin specs here
}

-- ============================================================================
-- PHASE 2: Runtime Configuration (runs when ${1:${TM_FILENAME_BASE}} buffer loads)
-- ============================================================================
local function setup()
	-- Vim Options

	-- LSP Configuration
	helpers.setup_lsp('${2:lsp_name}', {})

	-- Formatters & Linters
	local formatters = project.get_formatters('$1')
	if formatters then
		vim.b.formatters = formatters
	end

	local linters = project.get_linters('$1')
	if linters then
		vim.b.linters = linters
	end

	-- Buffer-local Keymaps
end

setup()

return M
$0]],
	},
}
