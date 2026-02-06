local helpers = _G.Config.ftplugin_helpers

helpers.ensure_treesitter({ 'yaml' })
helpers.setup_schemastore_lsp("yamlls", {
	-- settings = {
	-- 	yaml = {
	-- 		keyOrdering = false,
	-- 	},
	-- },
})
