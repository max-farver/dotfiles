local add_once = _G.Config.add_once
local project = _G.Config.project
local helpers = _G.Config.ftplugin_helpers

local venv_selector_defaults = {
	options = {
		notify_user_on_venv_activation = true,
		picker = "mini-pick",
	},
}

local function ensure_python_plugins()
	if vim.g._python_ftplugin_plugins_loaded then
		return
	end
	vim.g._python_ftplugin_plugins_loaded = true

	add_once({
		{ src = "https://github.com/linux-cultist/venv-selector.nvim" },
	})
	local venv_opts = project.merge_plugin_opts("linux-cultist/venv-selector.nvim", venv_selector_defaults)
	require("venv-selector").setup(venv_opts)

	add_once({
		{ src = "https://github.com/nvim-neotest/nvim-nio" },
		{ src = "https://github.com/nvim-lua/plenary.nvim" },
		{ src = "https://github.com/nvim-treesitter/nvim-treesitter" },
		{ src = "https://github.com/nvim-neotest/neotest" },
		{ src = "https://github.com/nvim-neotest/neotest-python" },
	})

	local neotest_python_opts = project.merge_plugin_opts("nvim-neotest/neotest-python", {})
	require("util.neotest").register_adapter("neotest-python", function()
		return require("neotest-python")(neotest_python_opts)
	end)
end

local function setup()
	ensure_python_plugins()
	helpers.ensure_treesitter({ "python" })

	helpers.setup_lsps({
		pyright = {},
		ruff = {},
	})

	vim.b.formatters = project.get_formatters("python") or { "black" }
	local linters = project.get_linters("python")
	if linters then
		vim.b.linters = linters
	end
end

setup()
