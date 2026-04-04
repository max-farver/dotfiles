local helpers = _G.Config.ftplugin_helpers

helpers.ensure_treesitter({ 'yaml' })
local schemas = {}
local ok_schemastore, schemastore = pcall(require, "schemastore")
if ok_schemastore and schemastore.yaml and type(schemastore.yaml.schemas) == "function" then
	schemas = schemastore.yaml.schemas()
end

helpers.setup_lsp("yamlls", {
	settings = {
		yaml = {
			schemaStore = { enable = false, url = "" },
			schemas = schemas,
			-- keyOrdering = false,
		},
	},
})
