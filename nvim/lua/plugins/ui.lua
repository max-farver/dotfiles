local icons = require("config.icons")
local statusline = require("config.statusline")

local function snacks_color(name)
	local ok, snacks = pcall(require, "snacks")
	if ok and snacks.util and snacks.util.color then
		return { fg = snacks.util.color(name) }
	end
end

return {
	{
		"folke/noice.nvim",
		event = "VeryLazy",
		opts = {
			lsp = {
				override = {
					["vim.lsp.util.convert_input_to_markdown_lines"] = true,
					["vim.lsp.util.stylize_markdown"] = true,
				},
			},

			presets = {
				bottom_search = true, -- use a classic bottom cmdline for search
				command_palette = true, -- position the cmdline and popupmenu together
				long_message_to_split = true, -- long messages will be sent to a split
				inc_rename = false, -- enables an input dialog for inc-rename.nvim
				lsp_doc_border = false, -- add a border to hover docs and signature help
			},
		},
		dependencies = {
			-- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
			"MunifTanjim/nui.nvim",
		}
	},
	-- {
	-- 	"b0o/incline.nvim",
	-- 	config = function()
	-- 		local helpers = require("incline.helpers")
	-- 		local devicons = require("nvim-web-devicons")
	--
	-- 		require("incline").setup({
	-- 			window = {
	-- 				padding = 0,
	-- 				margin = { horizontal = 0 },
	-- 			},
	-- 			render = function(props)
	-- 				local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
	-- 				if filename == "" then
	-- 					filename = "[No Name]"
	-- 				end
	-- 				local ft_icon, ft_color = devicons.get_icon_color(filename)
	-- 				local modified = vim.bo[props.buf].modified
	-- 				return {
	-- 					ft_icon and { " ", ft_icon, " ", guibg = ft_color, guifg = helpers.contrast_color(ft_color) } or
	-- 					"",
	-- 					" ",
	-- 					{ filename, gui = modified and "bold,italic" or "bold" },
	-- 					" ",
	-- 					guibg = "#44406e",
	-- 				}
	-- 			end,
	-- 		})
	-- 	end,
	-- 	-- Optional: Lazy load Incline
	-- 	event = "VeryLazy",
	-- },
	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		init = function()
			vim.g.lualine_laststatus = vim.o.laststatus
			if vim.fn.argc(-1) > 0 then
				-- set an empty statusline till lualine loads
				vim.o.statusline = " "
			else
				-- hide the statusline on the starter page
				vim.o.laststatus = 0
			end
		end,
		opts = function()
			-- PERF: we don't need this lualine require madness 🤷
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

			local opts = {
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
			}

			return opts
		end,
	},
}
