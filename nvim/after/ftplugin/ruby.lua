local add_once = _G.Config.add_once
local helpers = _G.Config.ftplugin_helpers
local project = _G.Config.project

local function ensure_ruby_plugins()
	if vim.g._ruby_ftplugin_plugins_loaded then
		return
	end
	vim.g._ruby_ftplugin_plugins_loaded = true

	add_once({
		{ src = "https://github.com/tpope/vim-bundler" },
		{ src = "https://github.com/tpope/vim-dispatch" },
		{ src = "https://github.com/tpope/vim-rails" },
	})

	add_once({
		{ src = "https://github.com/nvim-neotest/nvim-nio" },
		{ src = "https://github.com/nvim-lua/plenary.nvim" },
		{ src = "https://github.com/nvim-treesitter/nvim-treesitter" },
		{ src = "https://github.com/nvim-neotest/neotest" },
		{ src = "https://github.com/olimorris/neotest-rspec" },
	})

	local neotest_rspec_opts = project.merge_plugin_opts("olimorris/neotest-rspec", {})
	require("util.neotest").register_adapter("neotest-rspec", function()
		return require("neotest-rspec")(neotest_rspec_opts)
	end)
end

local function setup()
	ensure_ruby_plugins()
	helpers.ensure_treesitter({ "ruby" })

	helpers.setup_lsp("ruby-lsp", {
		cmd = { "ruby-lsp" },
		filetypes = { "ruby", "eruby" },
		root_markers = { "Gemfile", ".git" },
		init_options = {
			formatter = "auto",
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
