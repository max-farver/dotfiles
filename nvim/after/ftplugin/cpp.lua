local project = _G.Config.project
local helpers = _G.Config.ftplugin_helpers

local function setup()
	helpers.ensure_treesitter({ 'cpp' })

	helpers.setup_lsp("clangd", {
		cmd = { "clangd", "--background-index" },
		filetypes = { "cpp" },
	})

	vim.b.formatters = project.get_formatters("cpp") or { "clang_format" }

	local linters = project.get_linters("cpp")
	if linters then
		vim.b.linters = linters
	end
end

setup()
