local add = MiniDeps.add
local helpers = _G.Config.ftplugin_helpers
local project = _G.Config.project

local function ensure_ruby_plugins()
	if vim.b._ruby_ftplugin_plugins_loaded then
		return
	end
	vim.b._ruby_ftplugin_plugins_loaded = true

	add({
		source = "tpope/vim-rails",
		depends = {
			"tpope/vim-bundler",
			"tpope/vim-dispatch",
		},
	})
end

local function setup()
	ensure_ruby_plugins()

	helpers.setup_lsp("ruby_lsp", {
		cmd = { vim.fn.expand("~/.asdf/shims/ruby-lsp") },
	})

	local formatters = project.get_formatters("ruby")
	if formatters then
		vim.b.formatters = formatters
	end

	local linters = project.get_linters("ruby")
	if linters then
		vim.b.linters = linters
	end
end

setup()
