-- ============================================================================
-- PHASE 1: Plugin Declarations (evaluated at startup by lazy.nvim)
-- ============================================================================
local M = {}

M.plugins = {}

-- ============================================================================
-- PHASE 2: Runtime Configuration (runs when dockerfile buffer loads)
-- ============================================================================
local function setup()
	local helpers = require("util.ftplugin_helpers")
	local project = require("util.project")

	-- LSP Configuration (dockerls + docker-compose)
	helpers.setup_lsps({
		dockerls = {},
		docker_compose_language_service = {},
	})

	-- Linters
	vim.b.linters = project.get_linters('dockerfile') or { 'hadolint' }
end

-- Execute setup when buffer loads
setup()

-- Export for lazy.nvim to read at startup
return M
