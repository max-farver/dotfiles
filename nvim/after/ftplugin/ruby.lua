local add = MiniDeps.add
local helpers = _G.Config.ftplugin_helpers
local project = _G.Config.project

local function ensure_ruby_plugins()
	if vim.g._ruby_ftplugin_plugins_loaded then
		return
	end
	vim.g._ruby_ftplugin_plugins_loaded = true

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

	helpers.setup_lsp("ruby-lsp", {
		cmd = { '/Users/maxwell.farver/.rbenv/shims/ruby-lsp' },
		-- cmd = { 'ruby-lsp' },
		filetypes = { 'ruby', 'eruby' },
		root_markers = { 'Gemfile', '.git' },
		init_options = {
			formatter = 'auto',
		},
		addonSettings = {
			["Ruby LSP Rails"] = {
				enablePendingMigrationsPrompt = false,
			},
		},
		reuse_client = function(client, config)
			config.cmd_cwd = config.root_dir
			return client.config.cmd_cwd == config.cmd_cwd
		end,
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
