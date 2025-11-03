-- ============================================================================
-- PHASE 1: Plugin Declarations (evaluated at startup by lazy.nvim)
-- ============================================================================
local M = {}

M.plugins = {}

-- ============================================================================
-- PHASE 2: Runtime Configuration (runs when gitcommit buffer loads)
-- ============================================================================
local function setup()
	-- Vim Options
	vim.opt_local.wrap = true
	vim.opt_local.spell = true
end

-- Execute setup when buffer loads
setup()

-- Export for lazy.nvim to read at startup
return M
