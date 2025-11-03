-- ============================================================================
-- PHASE 1: Plugin Declarations (evaluated at startup by lazy.nvim)
-- ============================================================================
local M = {}

M.plugins = {}

-- ============================================================================
-- PHASE 2: Runtime Configuration (runs when yaml buffer loads)
-- ============================================================================
local function setup()
	local helpers = require("config.ftplugin_helpers")

	-- LSP Configuration (yamlls with schemastore)
	helpers.setup_schemastore_lsp("yamlls", {
		settings = {
			yaml = {
				keyOrdering = false,
			},
		},
	})
end

-- Execute setup when buffer loads
setup()

-- Export for lazy.nvim to read at startup
return M
