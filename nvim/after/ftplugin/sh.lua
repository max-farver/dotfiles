local helpers = _G.Config.ftplugin_helpers

helpers.ensure_treesitter({ 'bash' })
helpers.setup_lsp("bashls")
