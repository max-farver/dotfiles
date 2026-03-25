local helpers = _G.Config.ftplugin_helpers

helpers.ensure_treesitter({ 'yaml' })
helpers.setup_lsp("yamlls", {
	settings = {
		yaml = {
			schemaStore = { enable = false, url = "" },
			schemas = require("schemastore").yaml.schemas(),
			-- keyOrdering = false,
		},
	},
})
