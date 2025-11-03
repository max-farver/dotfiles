-- ============================================================================
-- Project Override Registry
-- ============================================================================
-- Provides utilities for ftplugin files to merge project-specific overrides
-- from .nvim.lua files with their default configurations.
--
-- Usage in .nvim.lua files:
--   vim.g.project_plugin_opts = { ['plugin/name'] = { opts } }
--   vim.g.project_lsp_servers = { server_name = { settings } }
--   vim.g.project_formatters = { filetype = { "formatter1", "formatter2" } }
--   vim.g.project_linters = { filetype = { "linter1", "linter2" } }
-- ============================================================================

local M = {}

-- Initialize global registries if they don't exist
vim.g.project_plugin_opts = vim.g.project_plugin_opts or {}
vim.g.project_lsp_servers = vim.g.project_lsp_servers or {}
vim.g.project_formatters = vim.g.project_formatters or {}
vim.g.project_linters = vim.g.project_linters or {}

-- ============================================================================
-- Helper Functions
-- ============================================================================

--- Deep merge two tables recursively, with values from `override` taking precedence
--- This is a true deep merge that recursively merges nested tables all the way down,
--- unlike vim.tbl_deep_extend which replaces tables at matching keys.
--- @param default table The default configuration
--- @param override table The override configuration
--- @return table The merged configuration
function M.merge(default, override)
	if not override or vim.tbl_isempty(override) then
		return default
	end

	-- Deep clone default to avoid mutation
	local result = vim.deepcopy(default)

	-- Recursively merge override into result
	local function deep_merge(target, source)
		for k, v in pairs(source) do
			if type(v) == "table" and type(target[k]) == "table" and not vim.islist(v) then
				-- Both are tables (and not arrays), merge recursively
				deep_merge(target[k], v)
			else
				-- Override value (for primitives, arrays, or when target doesn't have this key)
				target[k] = v
			end
		end
	end

	deep_merge(result, override)
	return result
end

--- Get plugin options override for a specific plugin
--- @param plugin_name string The plugin identifier (e.g., 'ray-x/go.nvim')
--- @return table|nil The override options, or nil if none exist
function M.get_plugin_override(plugin_name)
	local overrides = vim.g.project_plugin_opts or {}
	return overrides[plugin_name]
end

--- Get LSP server configuration override
--- @param server_name string The LSP server name (e.g., 'gopls', 'pyright')
--- @return table|nil The override configuration, or nil if none exist
function M.get_lsp_override(server_name)
	local overrides = vim.g.project_lsp_servers or {}
	return overrides[server_name]
end

--- Get formatter override for a filetype
--- @param filetype string The filetype (e.g., 'go', 'python')
--- @return table|nil The list of formatters, or nil if none exist
function M.get_formatters(filetype)
	local overrides = vim.g.project_formatters or {}
	return overrides[filetype]
end

--- Get linter override for a filetype
--- @param filetype string The filetype (e.g., 'go', 'python')
--- @return table|nil The list of linters, or nil if none exist
function M.get_linters(filetype)
	local overrides = vim.g.project_linters or {}
	return overrides[filetype]
end

--- Merge plugin opts with project overrides
--- @param plugin_name string The plugin identifier
--- @param default_opts table The default plugin options
--- @return table The merged options
function M.merge_plugin_opts(plugin_name, default_opts)
	local override = M.get_plugin_override(plugin_name)
	return M.merge(default_opts, override)
end

--- Merge LSP server config with project overrides
--- @param server_name string The LSP server name
--- @param default_config table The default LSP configuration
--- @return table The merged configuration
function M.merge_lsp_config(server_name, default_config)
	local override = M.get_lsp_override(server_name)
	return M.merge(default_config, override)
end

return M
