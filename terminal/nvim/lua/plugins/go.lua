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
        build_tags = "unit,integration,endtoendtest",
        dap_debug = false,
      })
    end,
    event = { "CmdlineEnter" },
    ft = { "go", "gomod" },
    build = ':lua require("go.install").update_all_sync()', -- if you need to install/update all binaries
  },
  {
    "leoluz/nvim-dap-go",
    opts = {},
  },
  {
    "nvim-neotest/neotest",
    dependencies = {
      "fredrikaverpil/neotest-golang", -- Installation
      dependencies = {
        "leoluz/nvim-dap-go",
        "uga-rosa/utf8.nvim",
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

        -- experimental
        dev_notifications = true,
      }
    end,
    config = function(_, opts)
      if opts.adapters then
        local adapters = {}
        for name, config in pairs(opts.adapters or {}) do
          if type(name) == "number" then
            if type(config) == "string" then
              config = require(config)
            end
            adapters[#adapters + 1] = config
          elseif config ~= false then
            local adapter = require(name)
            if type(config) == "table" and not vim.tbl_isempty(config) then
              local meta = getmetatable(adapter)
              if adapter.setup then
                adapter.setup(config)
              elseif adapter.adapter then
                adapter.adapter(config)
                adapter = adapter.adapter
              elseif meta and meta.__call then
                adapter(config)
              else
                error("Adapter " .. name .. " does not support setup")
              end
            end
            adapters[#adapters + 1] = adapter
          end
        end
        opts.adapters = adapters
      end

      require("neotest").setup(opts)
    end,
  },
}
