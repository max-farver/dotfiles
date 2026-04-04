local helpers = _G.Config.ftplugin_helpers
local filetype = vim.bo.filetype

helpers.ensure_treesitter({ 'json' })
vim.opt_local.conceallevel = 0

if filetype == "json" or filetype == "jsonc" then
	local schemas = {}
	local ok_schemastore, schemastore = pcall(require, "schemastore")
	if ok_schemastore and schemastore.json and type(schemastore.json.schemas) == "function" then
		schemas = schemastore.json.schemas()
	end

	helpers.setup_lsp("jsonls", {
		settings = {
			json = {
				schemas = schemas,
				validate = { enable = true },
			},
		},
	})
end
