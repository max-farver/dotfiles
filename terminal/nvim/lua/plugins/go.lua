return {
  {
    "ray-x/go.nvim",
    dependencies = { -- optional packages
      "ray-x/guihua.lua",
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("go").setup({
        goimports = "goimports",
        lsp_gofumpt = false,
        null_ls = false,
      })
    end,
    event = { "CmdlineEnter" },
    ft = { "go", "gomod" },
    build = ':lua require("go.install").update_all_sync()', -- if you need to install/update all binaries
  },
  -- {
  --   "nvim-neotest/neotest",
  --   dependencies = {
  --     "nvim-neotest/nvim-nio",
  --     "nvim-lua/plenary.nvim",
  --     "antoinemadec/FixCursorHold.nvim",
  --     "nvim-treesitter/nvim-treesitter",
  --     { "fredrikaverpil/neotest-golang", version = "*" }, -- Installation
  --   },
  --   config = function()
  --     local neotest_golang_opts = {
  --       testify_enabled = true,
  --     } -- Specify custom configuration
  --     require("neotest").setup({
  --       adapters = {
  --         require("neotest-golang")(neotest_golang_opts), -- Registration
  --       },
  --     })
  --   end,
  -- },
}
