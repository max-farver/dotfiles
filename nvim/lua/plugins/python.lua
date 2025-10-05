return {

	-- {
	-- 	"mfussenegger/nvim-dap-python",
	-- 	ft = { "python" },
	-- 	dependencies = { "mfussenegger/nvim-dap" },
	-- 	-- keymaps defined in config/keymaps.lua
	-- 	config = function()
	-- 		local python = vim.env.VIRTUAL_ENV and (vim.env.VIRTUAL_ENV .. "/bin/python") or
	-- 		"/etc/profiles/per-user/mfarver/bin/python"
	-- 		require("dap-python").setup(python)
	-- 	end,
	-- },
	--
	{
		"linux-cultist/venv-selector.nvim",
		ft = "python",
		cmd = "VenvSelect",
		opts = {
			options = {
				notify_user_on_venv_activation = true,
				picker = "mini-pick"
			},
		},
	},

	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-neotest/neotest-python",
		},
		opts = function(_, opts)
			opts.adapters = opts.adapters or {}
			opts.adapters["neotest-python"] = vim.tbl_deep_extend("force", {
				python = "/etc/profiles/per-user/mfarver/bin/python",
			}, opts.adapters["neotest-python"] or {})
		end,
	},
}
