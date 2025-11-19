local add = MiniDeps.add
local later = MiniDeps.later
local os = _G.Config.os

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
	else
		add({
			source = "obsidian-nvim/obsidian.nvim",
		})
		local obsidian_opts = {
			workspaces = {
				{
					name = "personal",
					path = vim.fn.expand("~") .. "/Documents/misc/obsidian/Default",
				},
			},
			picker = {
				name = "mini.pick",
			},
			legacy_commands = false,
		}
		require("obsidian").setup(obsidian_opts)
	end
end)
