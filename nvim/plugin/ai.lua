local add_once = _G.Config.add_once
local later = _G.Config.later

later(function()
	add_once({
		{ src = "https://github.com/folke/sidekick.nvim" },
		-- { src = "https://github.com/copilot-nvim/copilot-lsp" },
	})
	require("sidekick").setup({
		nes = {
			enabled = false,
		},
		cli = {
			mux = {
				backend = "tmux",
				enable = true,
			},
		},
	})

	local map = vim.keymap.set
	map({ "n", "t", "i", "x" }, "<c-.>", function() require("sidekick.cli").toggle() end, { desc = "Sidekick Toggle" })
	map("n", "<leader>aa", function() require("sidekick.cli").toggle() end, { desc = "Sidekick Toggle CLI" })
	map("n", "<leader>as", function() require("sidekick.cli").select({ filter = { installed = true } }) end,
		{ desc = "Select CLI" })
	map("n", "<leader>ad", function() require("sidekick.cli").close() end, { desc = "Detach a CLI Session" })
	map({ "x", "n" }, "<leader>at", function() require("sidekick.cli").send({ msg = "{this}" }) end,
		{ desc = "Send This" })
	map("n", "<leader>af", function() require("sidekick.cli").send({ msg = "{file}" }) end, { desc = "Send File" })
	map("x", "<leader>av", function() require("sidekick.cli").send({ msg = "{selection}" }) end,
		{ desc = "Send Visual Selection" })
	map({ "n", "x" }, "<leader>ap", function() require("sidekick.cli").prompt() end, { desc = "Sidekick Select Prompt" })
	map("n", "<tab>", function()
		if not require("sidekick").nes_jump_or_apply() then
			return "<Tab>"
		end
	end, {
		expr = true,
		desc = "Goto/Apply Next Edit Suggestion",
	})
end)
