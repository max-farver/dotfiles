local add = MiniDeps.add
local later = MiniDeps.later
local os = _G.Config.os
local ftplugin_helpers = _G.Config.ftplugin_helpers
local project = _G.Config.project

local function ensure_markdown_plugins()
	if vim.b._markdown_ftplugin_plugins_loaded then
		return
	end
	vim.b._markdown_ftplugin_plugins_loaded = true
	later(function()
		if os.is_linux then
			add({
				source = "obsidian-nvim/obsidian.nvim",
			})
			local obsidian_opts = project.merge_plugin_opts("obsidian-nvim/obsidian.nvim", {
				workspaces = {
					{
						name = "personal",
						path = vim.fn.expand("~") .. "/Documents/obsidian/Personal",
					},
				},
				picker = {
					name = "mini.pick",
				},
				legacy_commands = false,
			})
			require("obsidian").setup(obsidian_opts)
		end

		add("iamcco/markdown-preview.nvim")
		if vim.fn.exists(":MarkdownPreviewToggle") == 0 then
			vim.cmd("silent! call mkdp#util#install()")
		end

		add({
			source = "OXY2DEV/markview.nvim",
		})
		local presets = require("markview.presets")
		local markview_opts = project.merge_plugin_opts("OXY2DEV/markview.nvim", {
			preview = {
				modes = { "n", "no" },
				raw_previews = { markdown = { "code_blocks" } },
			},
			markdown = {
				checkboxes = presets.checkboxes.glow,
				headings = presets.headings.glow,
				horizontal_rules = presets.horizontal_rules.glow,
				tables = presets.tables.glow,
			},
		})
		require("markview").setup(markview_opts)
		vim.g.markview_lazy_loaded = true
	end)
end

local function setup()
	ensure_markdown_plugins()

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

	ftplugin_helpers.setup_lsp("marksman")

	vim.b.formatters = project.get_formatters("markdown") or { "prettier", "markdownlint-cli2", "markdown-toc" }
end

setup()
