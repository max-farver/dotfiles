local helpers = _G.Config.ftplugin_helpers

helpers.setup_lsp("nil_ls", {
	cmd = { "nil" },
	filetypes = { "nix" },
	root_markers = { "flake.nix" },
})
