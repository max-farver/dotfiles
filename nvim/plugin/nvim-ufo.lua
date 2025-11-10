local add = MiniDeps.add
local now = MiniDeps.now

now(function()
	add({
		source = "kevinhwang91/nvim-ufo",
		depends = { "kevinhwang91/promise-async" },
	})
	require("ufo").setup({
		close_fold_kinds_for_ft = {
			default = { "imports" },
		},
	})
end)
