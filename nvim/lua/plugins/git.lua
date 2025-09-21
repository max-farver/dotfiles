local icons = require("config.icons")

return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = icons.git.added },
        change = { text = icons.git.modified },
        delete = { text = icons.git.removed },
        topdelete = { text = icons.git.removed },
        changedelete = { text = icons.git.modified },
      },
      current_line_blame = true,
      preview_config = {
        border = "rounded",
      },
    },
  },

  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    opts = {
      enhanced_diff_hl = true,
    },
  },

  {
    "ruifm/gitlinker.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      mappings = nil, -- we'll use our own <leader>g mappings
    },
    config = function(_, opts)
      require("gitlinker").setup(opts)
    end,
  },
}
