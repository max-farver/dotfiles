--- Helper functions for ftplugin configurations
--- Reduces boilerplate in after/ftplugin/ files

local M = {}


local project = require("util.project")

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
		config.capabilities = vim.g.lsp_capabilities
	end

	local final_config = project.merge_lsp_config(lsp_name, config)

	-- Configure and enable the LSP
	vim.lsp.config(lsp_name, config)
	vim.lsp.enable(lsp_name)

	-- Mark as setup for this buffer
	vim.b[var_name] = true
end

--- Setup an LSP that uses schemastore (for JSON/YAML)
--- @param lsp_name string The name of the LSP (e.g., 'jsonls', 'yamlls')
--- @param extra_config table|nil Additional configuration to merge
function M.setup_schemastore_lsp(lsp_name, extra_config)
	local schemastore = require("schemastore")

	local config = vim.tbl_deep_extend("force", {
		capabilities = vim.g.lsp_capabilities,
	}, extra_config or {})

	-- Add schemastore schemas based on LSP type
	if lsp_name == "jsonls" then
		config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
			json = {
				schemas = schemastore.json.schemas(),
				validate = { enable = true },
			},
		})
	elseif lsp_name == "yamlls" then
		config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
			yaml = {
				schemaStore = {
					enable = false,
					url = "",
				},
				schemas = schemastore.yaml.schemas(),
			},
		})
	end

	M.setup_lsp(lsp_name, config)
end

--- Setup multiple LSPs with a simple configuration
--- @param lsp_configs table<string, table|nil> Map of LSP names to their configs
function M.setup_lsps(lsp_configs)
	for lsp_name, config in pairs(lsp_configs) do
		M.setup_lsp(lsp_name, config)
	end
end

return M
