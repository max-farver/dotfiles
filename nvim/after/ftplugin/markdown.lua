local add = MiniDeps.add
local later = MiniDeps.later
local ftplugin_helpers = _G.Config.ftplugin_helpers
local project = _G.Config.project

local function ensure_markdown_plugins()
	if vim.g._markdown_ftplugin_plugins_loaded then
		return
	end
	vim.g._markdown_ftplugin_plugins_loaded = true

	-- later(function()
	-- 	add("iamcco/markdown-preview.nvim")
	-- 	if vim.fn.exists(":MarkdownPreviewToggle") == 0 then
	-- 		vim.cmd("silent! call mkdp#util#install()")
	-- 	end
	-- end)

	later(function()
		add({
			source = "OXY2DEV/markview.nvim",
		})
		vim.g.markview_lazy_loaded = true
		local presets = require("markview.presets")
		local opts = {
			preview = {
				modes = { "n", "no" },
				-- raw_previews = { markdown = { "code_blocks" } },
			},
			map_gx = true,
			markdown = {
				checkboxes = presets.checkboxes.glow,
				headings = {
					heading_1 = { icon_hl = "@markup.link", icon = "[%d] " },
					heading_2 = { icon_hl = "@markup.link", icon = "[%d.%d] " },
					heading_3 = { icon_hl = "@markup.link", icon = "[%d.%d.%d] " }
				},
				horizontal_rules = presets.horizontal_rules.dashed,
				tables = presets.tables.single,
			},
		}
		require("markview").setup(opts)
		if vim.bo.filetype == "markdown" then
			vim.cmd("Markview attach")
		end
	end)
end

local function setup()
	ensure_markdown_plugins()
	ftplugin_helpers.ensure_treesitter({ 'markdown', 'markdown_inline' })

	vim.cmd("setlocal nospell wrap")
	vim.cmd("setlocal foldmethod=expr foldexpr=v:lua.vim.treesitter.foldexpr()")

	vim.b.minisurround_config = {
		custom_surroundings = {
			L = {
				input = { "%[().-()%]%(.-%)" },
				output = function()
					local link = require("mini.surround").user_input("Link: ")
					return { left = "[", right = "](" .. link .. ")" }
				end,
			},
		},
	}

	-- ftplugin_helpers.setup_lsp("marksman")

	vim.b.formatters = project.get_formatters("markdown")
end

setup()
