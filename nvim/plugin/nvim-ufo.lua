local add_once = _G.Config.add_once

local ufo_loaded = false
local function ensure_ufo_loaded()
	if ufo_loaded then
		return
	end
	ufo_loaded = true

	add_once({
		{ src = "https://github.com/kevinhwang91/promise-async" },
		{ src = "https://github.com/kevinhwang91/nvim-ufo" },
	})

	local ok, ufo = pcall(require, "ufo")
	if ok then
		ufo.setup({
			close_fold_kinds_for_ft = {
				default = { "imports" },
			},
		})
	end
end

vim.api.nvim_create_autocmd("VimEnter", {
	group = vim.api.nvim_create_augroup("ufo_deferred_setup", { clear = true }),
	once = true,
	callback = function()
		vim.defer_fn(ensure_ufo_loaded, 30)
	end,
})
