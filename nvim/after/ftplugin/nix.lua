local helpers = _G.Config.ftplugin_helpers

helpers.setup_lsp("nil_ls", {
	command = "nil",
	filetypes = { "nix" },
	rootPatterns = { "flake.nix" },
})
