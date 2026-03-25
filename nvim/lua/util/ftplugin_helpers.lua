--- Helper functions for ftplugin configurations
--- Reduces boilerplate in after/ftplugin/ files

local M = {}

local project = require("util.project")

local checked_parsers = {}

function M.ensure_treesitter(parsers)
	local to_install = {}
	for _, lang in ipairs(parsers) do
		if not checked_parsers[lang] then
			checked_parsers[lang] = true
			local ok, result = pcall(vim.treesitter.language.add, lang)
			if not (ok and result) then
				table.insert(to_install, lang)
			end
		end
	end
	if #to_install > 0 and _G.Config.nvim_ts then
		_G.Config.nvim_ts.install(to_install)
	end
	pcall(vim.treesitter.start)
end

--- Setup an LSP for the current buffer with project-specific config merging
--- @param lsp_name string The name of the LSP (e.g., 'gopls', 'pyright')
--- @param default_config table|nil The default LSP configuration
--- @param buffer_var_name string|nil Custom buffer variable name (defaults to 'lsp_<lsp_name>_setup')
function M.setup_lsp(lsp_name, default_config, buffer_var_name)
	local var_name = buffer_var_name or ("lsp_" .. lsp_name:gsub("[%-.]", "_") .. "_setup")

	-- Only setup once per buffer
	if vim.b[var_name] then
		return
	end

	-- Merge with global capabilities and project-specific config
	local config = default_config or {}
	if not config.capabilities then
		config.capabilities = _G.Config.lsp_capabilities
	end

	local final_config = project.merge_lsp_config(lsp_name, config)

	-- Configure and enable the LSP
	vim.lsp.config(lsp_name, final_config)
	vim.lsp.enable(lsp_name)

	-- Mark as setup for this buffer
	vim.b[var_name] = true
end

--- Setup multiple LSPs with a simple configuration
--- @param lsp_configs table<string, table|nil> Map of LSP names to their configs
function M.setup_lsps(lsp_configs)
	for lsp_name, config in pairs(lsp_configs) do
		M.setup_lsp(lsp_name, config)
	end
end

return M
