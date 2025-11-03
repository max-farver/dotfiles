-- ============================================================================
-- PHASE 1: Plugin Declarations (evaluated at startup by lazy.nvim)
-- ============================================================================
local M = {}

M.plugins = {}

-- ============================================================================
-- PHASE 2: Runtime Configuration (runs when json buffer loads)
-- ============================================================================
local function setup()
	local helpers = require("util.ftplugin_helpers")
	local filetype = vim.bo.filetype

	-- Vim Options - disable concealing for all JSON variants
	vim.opt_local.conceallevel = 0

	-- LSP Configuration - jsonls supports both json and jsonc
	if filetype == "json" or filetype == "jsonc" then
		helpers.setup_schemastore_lsp("jsonls")
	end
	-- json5 doesn't have LSP support, only the conceallevel setting
end

-- Execute setup when buffer loads
setup()

-- Export for lazy.nvim to read at startup
return M
