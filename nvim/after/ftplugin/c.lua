local project = _G.Config.project
local helpers = _G.Config.ftplugin_helpers

local function setup()
	helpers.ensure_treesitter({ 'c' })

	helpers.setup_lsp("clangd", {
		cmd = { "clangd", "--background-index" },
		filetypes = { "c" },
	})

	vim.b.formatters = project.get_formatters("c") or { "clang_format" }

	local linters = project.get_linters("c")
	if linters then
		vim.b.linters = linters
	end
end

setup()
