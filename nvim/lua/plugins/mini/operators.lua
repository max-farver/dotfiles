return {
	"nvim-mini/mini.operators",
	version = "*",
	opts = {
		replace = {
			prefix = "<s-r>",
			reindent_linewise = true,
		},
	},
	config = function(_, opts)
		require("mini.operators").setup(opts)
	end
}
