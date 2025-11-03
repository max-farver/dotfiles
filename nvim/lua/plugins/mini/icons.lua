return {
	"nvim-mini/mini.icons",
	lazy = true,
	opts = {
		file = {
			[".keep"] = { glyph = "󰊢" },
			["devcontainer.json"] = { glyph = "" },
		},
		filetype = {
			dotenv = { glyph = "" },
		},
	},
	config = function(_, opts)
		local mini_icons = require("mini.icons")
		mini_icons.setup(opts)
		mini_icons.mock_nvim_web_devicons()
	end,
}
