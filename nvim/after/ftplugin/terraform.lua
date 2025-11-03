-- ============================================================================
-- PHASE 1: Plugin Declarations (evaluated at startup by lazy.nvim)
-- ============================================================================
local M = {}

M.plugins = {}

-- ============================================================================
-- PHASE 2: Runtime Configuration (runs when terraform buffer loads)
-- ============================================================================
local function setup()
	local helpers = require("util.ftplugin_helpers")
	local project = require("util.project")

	-- LSP Configuration
	helpers.setup_lsp("terraformls")

	-- Formatters & Linters
	vim.b.formatters = project.get_formatters('terraform') or { 'terraform_fmt' }
	vim.b.linters = project.get_linters('terraform') or { 'terraform_validate' }
end

-- Execute setup when buffer loads
setup()

-- Export for lazy.nvim to read at startup
return M
