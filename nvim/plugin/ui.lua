local add = MiniDeps.add
local later = MiniDeps.later
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

later(function()
	add("rachartier/tiny-inline-diagnostic.nvim")
	require("tiny-inline-diagnostic").setup()
end)

if not vim.g.vscode then
	later(function()
		add("nvim-lualine/lualine.nvim")

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
			extensions = { "neo-tree", "lazy", "fzf" },
		})
	end)
end
