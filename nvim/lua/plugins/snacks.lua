return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
			statuscolumn = {},
    },
    config = function(_, opts)

      require("snacks").setup(opts)
    end,
  },
}

