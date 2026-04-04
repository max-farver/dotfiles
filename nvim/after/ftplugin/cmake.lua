local project = _G.Config.project
local helpers = _G.Config.ftplugin_helpers

local function setup()
	helpers.ensure_treesitter({ 'cmake' })

	helpers.setup_lsp("cmake", {
		cmd = { "cmake-language-server" },
		filetypes = { "cmake" },
		root_markers = { "CMakeLists.txt", ".git" },
	})

	vim.b.formatters = project.get_formatters("cmake") or { "cmake_format" }

	local linters = project.get_linters("cmake")
	if linters then
		vim.b.linters = linters
	end
end

setup()
