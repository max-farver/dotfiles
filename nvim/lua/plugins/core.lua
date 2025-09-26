return {
		  { "nvim-tree/nvim-web-devicons", lazy = true },
  { "nvim-lua/plenary.nvim", lazy = true },
  { "MunifTanjim/nui.nvim", lazy = true },
  { "antoinemadec/FixCursorHold.nvim", event = "VeryLazy" },

  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {},
    config = function(_, opts)
      require("lazydev").setup(opts)
    end,
  },

  {
    "folke/todo-comments.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
    config = function(_, opts)
      require("todo-comments").setup(opts)
    end,
  },

  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = { use_diagnostic_signs = true },
    config = function(_, opts)
      require("trouble").setup(opts)
    end,
  },

  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    config = function(_, opts)
      require("persistence").setup(opts)
    end,
  },

  {
    "folke/grug-far.nvim",
    cmd = "GrugFar",
    opts = {},
    config = function(_, opts)
      require("grug-far").setup(opts)
    end,
  },
}
