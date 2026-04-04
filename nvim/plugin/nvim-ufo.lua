local add = _G.Config.pack_add
local now = _G.Config.now

now(function()
	add({
		{ src = "https://github.com/kevinhwang91/promise-async" },
		{ src = "https://github.com/kevinhwang91/nvim-ufo" },
	})
	require("ufo").setup({
		close_fold_kinds_for_ft = {
			default = { "imports" },
		},
	})
end)
