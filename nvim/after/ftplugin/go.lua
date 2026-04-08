local add_once = _G.Config.add_once
local later = _G.Config.later
local project = _G.Config.project
local helpers = _G.Config.ftplugin_helpers

local go_nvim_defaults = {
	goimports = "goimports",
	lsp_gofumpt = false,
	build_tags = "unit,integration,endtoendtest",
	dap_debug = false,
	diagnostic = {
		hdlr = false,
		underline = true,
		virtual_text = false,
		update_in_insert = false,
		signs = true,
	},
}

local neotest_golang_defaults = {
	go_test_args = function()
		return {
			"-v",
			"-race",
			"-coverprofile=" .. vim.fn.getcwd() .. "/coverage.out",
			vim.env.GO_TEST_FLAGS or "",
		}
	end,
	dap_go_opts = {
		delve = {
			build_flags = { "-tags=unit,integration,endtoendtest" },
		},
	},
	runner = "gotestsum",
	gotestsum_args = { "--format=standard-verbose" },
	testify_enabled = true,
	log_level = vim.log.levels.TRACE,
	dev_notifications = true,
}

local function ensure_go_plugins()
	if vim.g._go_ftplugin_plugins_loaded then
		return
	end
	vim.g._go_ftplugin_plugins_loaded = true

	later(function()
		add_once({
			{ src = "https://github.com/ray-x/guihua.lua" },
			{ src = "https://github.com/nvim-treesitter/nvim-treesitter" },
			{ src = "https://github.com/ray-x/go.nvim" },
		})
		local go_opts = project.merge_plugin_opts("ray-x/go.nvim", go_nvim_defaults)
		require("go").setup(go_opts)

		add_once({ { src = "https://github.com/TheNoeTrevino/no-go.nvim" } })
		require("no-go").setup({
			enabled = true,
			identifiers = { "err" },
			virtual_text = {
				prefix = ": ",
				content_separator = " ",
				return_character = "󱞿 ",
				suffix = "",
			},
			highlight_group = "Comment",
			update_events = {
				"BufEnter",
				"BufWritePost",
				"TextChanged",
				"TextChangedI",
				"InsertLeave",
			},
			reveal_on_cursor = true,
		})
	end)
end

local function ensure_go_neotest_adapter()
	if vim.g._go_neotest_adapter_loaded then
		return
	end
	vim.g._go_neotest_adapter_loaded = true

	add_once({
		{ src = "https://github.com/nvim-neotest/nvim-nio" },
		{ src = "https://github.com/nvim-lua/plenary.nvim" },
		{ src = "https://github.com/nvim-treesitter/nvim-treesitter" },
		{ src = "https://github.com/nvim-neotest/neotest" },
		{ src = "https://github.com/leoluz/nvim-dap-go" },
		{ src = "https://github.com/uga-rosa/utf8.nvim" },
		{ src = "https://github.com/fredrikaverpil/neotest-golang" },
	})

	local neotest_opts = project.merge_plugin_opts("fredrikaverpil/neotest-golang", neotest_golang_defaults)
	require("util.neotest").register_adapter("neotest-golang", function()
		return require("neotest-golang")(neotest_opts)
	end)
end

local function setup()
	ensure_go_plugins()
	ensure_go_neotest_adapter()
	helpers.ensure_treesitter({ "go", "gomod", "gosum", "gowork" })

	vim.opt_local.expandtab = false
	vim.opt_local.tabstop = 4
	vim.opt_local.shiftwidth = 4

	helpers.setup_lsp("gopls", {
		filetypes = { "go", "gomod", "gowork", "gotmpl" },
		settings = {
			gopls = {
				buildFlags = { "-tags=unit,integration,endtoendtest" },
				directoryFilters = { "-**/node_modules", "-**/.git" },
				analyses = {
					unusedparams = true,
					shadow = true,
				},
				staticcheck = true,
				completeUnimported = true,
			},
		},
	})

	local formatters = project.get_formatters("go")
	if formatters then
		vim.b.formatters = formatters
	end

	local linters = project.get_linters("go")
	if linters then
		vim.b.linters = linters
	end

	if vim.fn.expand("%"):match("_test%.go$") then
		local tags = {}
		local buf = vim.api.nvim_get_current_buf()
		local pattern = [[^//\s*[+|(go:)]*build\s\+\(.\+\)]]
		local line_count = math.min(vim.api.nvim_buf_line_count(buf), 10)

		for i = 0, line_count - 1 do
			local line = vim.trim(vim.api.nvim_buf_get_lines(buf, i, i + 1, false)[1] or "")
			if line:find("package", 1, true) then
				break
			end
			local t = vim.fn.substitute(line, pattern, [[\1]], "")
			if t ~= line then
				t = vim.fn.substitute(t, [[ \+]], ",", "g")
				table.insert(tags, t)
			end
		end

		if #tags > 0 then
			vim.env.GO_TEST_FLAGS = "-tags=" .. table.concat(tags, ",")
		end
	end
end

setup()
