return {
	{
		dependencies = {
			{ "nvim-mini/mini.pick" }
		},
		dir = '/home/mfarver/Documents/repos/snowflake.nvim',
		config = function()
			require('db-studio').setup({
				target_vendor = 'sqlite',
				connections_path = "/home/mfarver/.config/db-studio/config.toml",
				picker = "mini_pick",
				default_open_target = 'viewer',
				viewer = { cmd = 'csvlens', args_template = '{file}' },
				lsp = { enabled = true },
			})
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter",
		opts = function(_, opts)
			if type(opts.ensure_installed) == "table" then
				for _, lang in ipairs({ "sql" }) do
					if not vim.tbl_contains(opts.ensure_installed, lang) then
						table.insert(opts.ensure_installed, lang)
					end
				end
			end
		end,
	},
	{
		"williamboman/mason.nvim",
		enabled = not require("config.os").is_linux,
		opts = function(_, opts)
			opts.ensure_installed = opts.ensure_installed or {}
			for _, tool in ipairs({ "sqlfluff" }) do
				if not vim.tbl_contains(opts.ensure_installed, tool) then
					table.insert(opts.ensure_installed, tool)
				end
			end
		end,
	},
}
