-- ============================================================================
-- PHASE 1: Plugin Declarations (evaluated at startup by lazy.nvim)
-- ============================================================================
local M = {}

M.plugins = {}

-- ============================================================================
-- PHASE 2: Runtime Configuration (runs when sh/bash buffer loads)
-- ============================================================================
local function setup()
	local helpers = require("util.ftplugin_helpers")

	-- LSP Configuration
	helpers.setup_lsp("bashls")
end

-- Execute setup when buffer loads
setup()

-- Export for lazy.nvim to read at startup
return M
