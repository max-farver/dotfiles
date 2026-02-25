local helpers = _G.Config.ftplugin_helpers

helpers.ensure_treesitter({ 'proto' })
helpers.setup_lsp("buf_ls", {
	filetypes = { "proto" },

})
