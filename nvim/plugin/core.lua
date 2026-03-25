local add = MiniDeps.add
local now, later = MiniDeps.now, MiniDeps.later
local nmap = _G.Config.nmap

-- Plugins that previously used `lazy = true` or `event = ...`
later(function()
	add("nvim-lua/plenary.nvim")
	add("MunifTanjim/nui.nvim")
	add("antoinemadec/FixCursorHold.nvim")
	add({
		source = "folke/todo-comments.nvim",
		depends = { "nvim-lua/plenary.nvim" },
	})
	require("todo-comments").setup({})
end)

later(function()
	add("folke/persistence.nvim")
	require("persistence").setup({})
end)

-- now(function()
-- 	add("folke/trouble.nvim")
-- 	require("trouble").setup({
-- 		use_diagnostic_signs = true,
-- 		auto_preview = false,
-- 	})
-- end)
--
now(function()
	add("folke/grug-far.nvim")
	require("grug-far").setup({})

	nmap('<leader>sg', '<cmd>GrugFar<CR>', 'Search (grug-far)')
end)
