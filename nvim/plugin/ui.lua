if vim.g.vscode then
	return
end

local add_once = _G.Config.add_once
local now, later = _G.Config.now, _G.Config.later
local icons = _G.Config.icons
local statusline = _G.Config.statusline

local function snacks_color(name)
	local ok, snacks = pcall(require, "snacks")
	if ok and snacks.util and snacks.util.color then
		return { fg = snacks.util.color(name) }
	end
end

local function init_lualine()
	vim.g.lualine_laststatus = vim.o.laststatus
	if vim.fn.argc(-1) > 0 then
		vim.o.statusline = " "
	else
		vim.o.laststatus = 0
	end
end

init_lualine()

now(function()
	local clue = require("mini.clue")

	local triggers = {
		{ mode = "n", keys = "<Leader>" },
		{ mode = "x", keys = "<Leader>" },
		{ mode = "o", keys = "<Leader>" },
		{ mode = "n", keys = "[" },
		{ mode = "n", keys = "]" },
		{ mode = "n", keys = "g" },
		{ mode = "x", keys = "g" },
		{ mode = "n", keys = "z" },
		{ mode = "x", keys = "z" },
		{ mode = "n", keys = "<C-w>" },
		{ mode = "i", keys = "<C-x>" },
	}

	local clues = {
		clue.gen_clues.builtin_completion(),
		clue.gen_clues.marks(),
		clue.gen_clues.registers(),
		clue.gen_clues.windows(),
		clue.gen_clues.z(),
		clue.gen_clues.g(),
		{ mode = "n", keys = "<Leader>a", desc = "AI" },
		{ mode = "n", keys = "<Leader>b", desc = "Buffers" },
		{ mode = "n", keys = "<Leader>c", desc = "Code" },
		{ mode = "n", keys = "<Leader>d", desc = "Debug" },
		{ mode = "n", keys = "<Leader>f", desc = "Find" },
		{ mode = "x", keys = "<Leader>f", desc = "Find" },
		{ mode = "n", keys = "<Leader>g", desc = "Git" },
		{ mode = "x", keys = "<Leader>g", desc = "Git" },
		{ mode = "n", keys = "<Leader>cl", desc = "LSP" },
		{ mode = "n", keys = "<Leader>o", desc = "Obsidian" },
		{ mode = "n", keys = "<Leader>x", desc = "Quickfix" },
		{ mode = "n", keys = "<Leader>s", desc = "Search" },
		{ mode = "n", keys = "<Leader><Tab>", desc = "Tab" },
		{ mode = "n", keys = "<Leader>t", desc = "Terminal/Test" },
		{ mode = "n", keys = "<Leader>u", desc = "UI" },
		{ mode = "n", keys = "<Leader>w", desc = "Windows" },
	}

	local max_desc = 0
	for _, entry in ipairs(clues) do
		if type(entry) == "table" and type(entry.desc) == "string" then
			if #entry.desc > max_desc then
				max_desc = #entry.desc
			end
		end
	end

	local cols = vim.o.columns
	local computed = max_desc + 22
	local width = math.max(40, math.min(math.floor(cols * 0.6), math.min(100, computed)))

	vim.o.timeoutlen = vim.o.timeoutlen > 0 and vim.o.timeoutlen or 300

	clue.setup({
		window = {
			delay = 100,
			config = { width = width, border = "rounded" },
		},
		triggers = triggers,
		clues = clues,
	})
end)

later(function()
	add_once({ { src = "https://github.com/rachartier/tiny-inline-diagnostic.nvim" } })
	require("tiny-inline-diagnostic").setup()
end)

later(function()
	add_once({ { src = "https://github.com/nvim-lualine/lualine.nvim" } })

		local lualine_require = require("lualine_require")
		lualine_require.require = require

		local dmode_enabled = false
		vim.api.nvim_create_autocmd("User", {
			pattern = "DebugModeChanged",
			callback = function(args)
				dmode_enabled = args.data.enabled
			end,
		})

		vim.o.laststatus = vim.g.lualine_laststatus

		require("lualine").setup({
			options = {
				theme = "auto",
				globalstatus = vim.o.laststatus == 3,
				disabled_filetypes = { statusline = { "dashboard", "alpha", "ministarter", "snacks_dashboard" } },
			},
			sections = {
				lualine_a = {
					{
						"mode",
						fmt = function(str)
							return dmode_enabled and "DEBUG" or str
						end,
						color = function(tb)
							return dmode_enabled and "dCursor" or tb
						end,
					},
				},
				lualine_b = { "branch" },
				lualine_c = {
					statusline.root_dir_component(),
					{
						"diagnostics",
						symbols = {
							error = icons.diagnostics.Error,
							warn = icons.diagnostics.Warn,
							info = icons.diagnostics.Info,
							hint = icons.diagnostics.Hint,
						},
					},
					{ "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
					statusline.pretty_path_component(),
				},
				lualine_x = {
					{
						function()
							return "  " .. require("dap").status()
						end,
						cond = function()
							return package.loaded["dap"] and require("dap").status() ~= ""
						end,
						color = snacks_color("Debug"),
					},
				},
				lualine_y = {
					{ "progress", separator = " ",                  padding = { left = 1, right = 0 } },
					{ "location", padding = { left = 0, right = 1 } },
				},
				lualine_z = {
					function()
						return " " .. os.date("%R")
					end,
				},
			},
			extensions = {},
		})
	end)
