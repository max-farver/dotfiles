-- ============================================================================
-- PHASE 1: Plugin Declarations (evaluated at startup by lazy.nvim)
-- ============================================================================
local M = {}

M.plugins = {}

-- ============================================================================
-- PHASE 2: Runtime Configuration (runs when lua buffer loads)
-- ============================================================================
local function setup()
	local helpers = require("config.ftplugin_helpers")

	-- LSP Configuration
	helpers.setup_lsp("lua_ls", {
		settings = {
			Lua = {
				completion = { callSnippet = 'Replace' },
				diagnostics = { globals = { 'vim' } },
				workspace = { checkThirdParty = false },
			},
		},
	})
end

-- Execute setup when buffer loads
setup()

-- Export for lazy.nvim to read at startup
return M
