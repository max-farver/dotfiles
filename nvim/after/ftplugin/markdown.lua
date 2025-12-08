local add = MiniDeps.add
local later = MiniDeps.later
local ftplugin_helpers = _G.Config.ftplugin_helpers
local project = _G.Config.project

local function ensure_markdown_plugins()
	if vim.g._markdown_ftplugin_plugins_loaded then
		return
	end
	vim.g._markdown_ftplugin_plugins_loaded = true
	later(function()
		add("iamcco/markdown-preview.nvim")
		if vim.fn.exists(":MarkdownPreviewToggle") == 0 then
			vim.cmd("silent! call mkdp#util#install()")
		end
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
