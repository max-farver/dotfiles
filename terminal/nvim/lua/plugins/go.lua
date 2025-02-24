return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      { "fredrikaverpil/neotest-golang", version = "*" }, -- Installation
    },
    config = function()
      local neotest_golang_opts = {
        testify_enabled = true,
      } -- Specify custom configuration
      require("neotest").setup({
        adapters = {
          require("neotest-golang")(neotest_golang_opts), -- Registration
        },
      })
    end,
  },
}
