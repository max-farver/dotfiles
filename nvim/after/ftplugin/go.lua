local add = MiniDeps.add
local later = MiniDeps.later
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


local function printTable(t, indent)
	indent = indent or ""
	for k, v in pairs(t) do
		if type(v) == "table" then
			print(indent .. k .. " = {")
			printTable(v, indent .. "  ")
			print(indent .. "}")
		else
			print(indent .. k .. " = " .. tostring(v))
		end
	end
end

local function ensure_go_plugins()
	if vim.g._go_ftplugin_plugins_loaded then
		return
	end
	vim.g._go_ftplugin_plugins_loaded = true

	later(function()
		add({
			source = "ray-x/go.nvim",
			depends = {
				"ray-x/guihua.lua",
				"neovim/nvim-lspconfig",
				"nvim-treesitter/nvim-treesitter",
			},
			hooks = {
				post_checkout = function()
					pcall(function()
						require("go.install").update_all_sync()
					end)
				end,
			},
		})
		local go_opts = project.merge_plugin_opts("ray-x/go.nvim", go_nvim_defaults)
		require("go").setup(go_opts)
	end)
end

local function setup()
	ensure_go_plugins()

	vim.opt_local.expandtab = false
	vim.opt_local.tabstop = 4
	vim.opt_local.shiftwidth = 4

	helpers.setup_lsp("gopls", {
		filetypes = { "go", "gomod", "gowork", "gotmpl" },
		settings = {
			gopls = {
				buildFlags = { "-tags=unit,integration,endtoend" },
				directoryFilters = { "-**/node_modules", "-**/.git" },
				analyses = {
					unusedparams = true,
					shadow = true,
				},
				staticcheck = true,
				gofumpt = true,
				usePlaceholders = true,
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

	local opts = { buffer = true, silent = true }
	vim.keymap.set("n", "<leader>gt", "<cmd>GoTest<cr>", vim.tbl_extend("force", opts, { desc = "Run Go tests" }))
	vim.keymap.set("n", "<leader>gT", "<cmd>GoTestFile<cr>", vim.tbl_extend("force", opts, { desc = "Run Go test file" }))

	if vim.fn.expand("%"):match("_test%.go$") then
		local tags = {}
		local buf = vim.api.nvim_get_current_buf()
		local pattern = [[^//\s*[+|(go:)]*build\s\+\(.\+\)]]
		local line_count = vim.api.nvim_buf_line_count(buf)
		line_count = math.min(line_count, 10)

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
