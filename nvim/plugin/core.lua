local add_once = _G.Config.pack_add_once or _G.Config.pack_add
local now, later = _G.Config.now, _G.Config.later
local now_if_args = _G.Config.now_if_args
local nmap = _G.Config.nmap

-- Core mini foundations
now(function()
	require("mini.basics").setup()
end)

now(function()
	local ext3_blocklist = { scm = true, txt = true, yml = true }
	local ext4_blocklist = { json = true, yaml = true }
	require("mini.icons").setup({
		file = {
			[".keep"] = { glyph = "󰊢" },
			["devcontainer.json"] = { glyph = "" },
		},
		filetype = {
			dotenv = { glyph = "" },
		},
		use_file_extension = function(ext, _)
			return not (ext3_blocklist[ext:sub(-3)] or ext4_blocklist[ext:sub(-4)])
		end,
	})

	later(MiniIcons.mock_nvim_web_devicons)
	later(MiniIcons.tweak_lsp_kind)
end)

now_if_args(function()
	MiniMisc.setup_auto_root()
	MiniMisc.setup_restore_cursor()
end)

now(function()
	require("mini.notify").setup()
end)

now(function()
	require("mini.extra").setup()
end)

-- Plugins that previously used `lazy = true` or `event = ...`
later(function()
	add_once({ { src = "https://github.com/nvim-lua/plenary.nvim" } })
	add_once({ { src = "https://github.com/MunifTanjim/nui.nvim" } })
	add_once({
		{ src = "https://github.com/folke/todo-comments.nvim" },
	})
	require("todo-comments").setup({})
end)

later(function()
	add_once({ { src = "https://github.com/folke/persistence.nvim" } })
	require("persistence").setup({})
end)

-- now(function()
-- 	add_once({ { src = "https://github.com/folke/trouble.nvim" } })
-- 	require("trouble").setup({
-- 		use_diagnostic_signs = true,
-- 		auto_preview = false,
-- 	})
-- end)
--
later(function()
	add_once({ { src = "https://github.com/folke/grug-far.nvim" } })
	require("grug-far").setup({})

	nmap('<leader>sg', '<cmd>GrugFar<CR>', 'Search (grug-far)')
end)
