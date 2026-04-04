local add = _G.Config.pack_add
local now, later = _G.Config.now, _G.Config.later
local nmap = _G.Config.nmap

-- Plugins that previously used `lazy = true` or `event = ...`
later(function()
	add({ { src = "https://github.com/nvim-lua/plenary.nvim" } })
	add({ { src = "https://github.com/MunifTanjim/nui.nvim" } })
	add({
		{ src = "https://github.com/folke/todo-comments.nvim" },
	})
	require("todo-comments").setup({})
end)

later(function()
	add({ { src = "https://github.com/folke/persistence.nvim" } })
	require("persistence").setup({})
end)

-- now(function()
-- 	add({ { src = "https://github.com/folke/trouble.nvim" } })
-- 	require("trouble").setup({
-- 		use_diagnostic_signs = true,
-- 		auto_preview = false,
-- 	})
-- end)
--
later(function()
	add({ { src = "https://github.com/folke/grug-far.nvim" } })
	require("grug-far").setup({})

	nmap('<leader>sg', '<cmd>GrugFar<CR>', 'Search (grug-far)')
end)
