-- VSCode integration and adjustments
-- Loaded only when running under VSCode Neovim extension
if not vim.g.vscode then
	return {}
end

local specs = {}

-- Reduce Snacks features in VSCode for performance and UX parity
table.insert(specs, {
	"folke/snacks.nvim",
	opts = {
		dashboard = { enabled = false },
		indent = { enabled = false },
		input = { enabled = false },
		notifier = { enabled = false },
		picker = { enabled = false },
		quickfile = { enabled = false },
		scroll = { enabled = false },
		statuscolumn = { enabled = false },
		words = { enabled = false },
	},
	init = function()
		vim.g.snacks_animate = false
	end,
})

-- Disable heavy UI plugins in VSCode
for _, p in ipairs({
	"folke/noice.nvim",
	"nvim-lualine/lualine.nvim",
	"b0o/incline.nvim",
}) do
	table.insert(specs, { p, enabled = false })
end

-- Optionally reduce treesitter highlight in VSCode
table.insert(specs, {
	"nvim-treesitter/nvim-treesitter",
	opts = function(_, opts)
		opts = opts or {}
		opts.highlight = opts.highlight or {}
		opts.highlight.enable = false
	end,
})

-- VSCode-specific keymaps
vim.api.nvim_create_autocmd("User", {
	pattern = "VeryLazy",
	callback = function()
		local ok, vscode = pcall(require, "vscode")
		if not ok then return end
		local map = function(mode, lhs, rhs, opts)
			opts = opts or {}
			opts.silent = opts.silent ~= false
			vim.keymap.set(mode, lhs, rhs, opts)
		end
		map("n", "<leader><space>", ":Find<cr>")
		map("n", "<leader>/", function() vscode.action('workbench.action.findInFiles') end)
		map("n", "<leader>ss", function() vscode.action('workbench.action.gotoSymbol') end)
		map("n", "u", ":call VSCodeNotify('undo')<CR>")
		map("n", "<C-r>", ":call VSCodeNotify('redo')<CR>")
		map("n", "<S-h>", ":call VSCodeNotify('workbench.action.previousEditor')<CR>")
		map("n", "<S-l>", ":call VSCodeNotify('workbench.action.nextEditor')<CR>")
		-- Terminal toggle similar to Snacks.terminal
		map("n", "<c-/>", function() vscode.action('workbench.action.terminal.toggleTerminal') end,
			{ desc = "VSCode Terminal" })
	end,
})

return specs
