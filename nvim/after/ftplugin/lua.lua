local helpers = _G.Config.ftplugin_helpers

helpers.ensure_treesitter({ 'lua' })
helpers.setup_lsp("lua_ls", {
	settings = {
		Lua = {
			completion = { callSnippet = "Replace" },
			diagnostics = { globals = { "vim" } },
			workspace = { checkThirdParty = false },
		},
	},
})
