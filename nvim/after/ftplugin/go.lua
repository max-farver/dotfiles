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

		add("TheNoeTrevino/no-go.nvim")
		require("no-go").setup({ -- required w/o lazy.nvim
			-- Enable the plugin behavior by default
			enabled = true,

			-- Identifiers to match in if statements (e.g., "if err != nil", "if error != nil")
			-- Only collapse blocks where the identifier is in this list
			identifiers = { "err" },

			-- Virtual text for collapsed error handling
			-- Built as: prefix + content + content_separator + return_character + suffix
			-- The default follows Jetbrains GoLand style of concealment:
			virtual_text = {
				prefix = ": ",
				content_separator = " ",
				return_character = "󱞿 ",
				suffix = "",
			},

			-- Highlight group for the collapsed text
			highlight_group = "Comment",

			-- Auto-update on these events
			update_events = {
				"BufEnter",
				"BufWritePost",
				"TextChanged",
				"TextChangedI",
				"InsertLeave",
			},

			-- Reveal concealed lines when cursor is on the if err != nil line
			-- This allows you to inspect the error handling by hovering over the collapsed line
			reveal_on_cursor = true,
		})
	end)
end

local function setup()
	ensure_go_plugins()
	helpers.ensure_treesitter({ 'go', 'gomod', 'gosum', 'gowork' })

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

	-- Update test tags based on the header of the current file
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
