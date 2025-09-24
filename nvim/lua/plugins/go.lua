return {
  {
    "ray-x/go.nvim",
    dependencies = {
      "ray-x/guihua.lua",
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
    },
    ft = { "go", "gomod" },
    event = { "CmdlineEnter" },
    build = ':lua require("go.install").update_all_sync()',
    config = function()
      require("go").setup({
        goimports = "goimports",
        lsp_gofumpt = false,
        build_tags = "unit,integration,endtoendtest",
        dap_debug = false,
        -- let go.nvim configure and start gopls
        lsp_cfg = true,
	treesitter=false,
      })
    end,
  },

  {
    "leoluz/nvim-dap-go",
    ft = { "go" },
    dependencies = { "mfussenegger/nvim-dap" },
    opts = {},
  },

  {
    "nvim-neotest/neotest",
    dependencies = {
      {
        "fredrikaverpil/neotest-golang",
        dependencies = {
          "leoluz/nvim-dap-go",
          "uga-rosa/utf8.nvim",
        },
      },
    },
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}
      opts.adapters["neotest-golang"] = {
        go_test_args = function()
          return {
            "-v",
            "-count=1",
            "-race",
            "-coverprofile=" .. vim.fn.getcwd() .. "/coverage.out",
            vim.env.GO_TEST_FLAGS or "",
          }
        end,
        dap_go_opts = {
          delve = {
            build_flags = { "-tags=unit,integration,endtoendtest" },
          },
        },
        runner = "gotestsum",
        gotestsum_args = { "--format=standard-verbose" },
        testify_enabled = true,
        sanitize_output = true,
        log_level = vim.log.levels.TRACE,
        dev_notifications = true,
      }
    end,
  },
}
