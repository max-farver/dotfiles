return {
  {
    'ray-x/go.nvim',
    dependencies = { -- optional packages
      'ray-x/guihua.lua',
      'neovim/nvim-lspconfig',
      'nvim-treesitter/nvim-treesitter',
    },
    lazy = true,
    config = function()
      require('go').setup {
        goimports = 'goimports',
        lsp_gofumpt = false,
        build_tags = 'unit,integration,endtoendtest',
        dap_debug = false,
      }
      vim.lsp.enable 'gopls'
    end,
    event = { 'CmdlineEnter' },
    ft = { 'go', 'gomod' },
    build = ':lua require("go.install").update_all_sync()', -- if you need to install/update all binaries
  },
  {
    'leoluz/nvim-dap-go',
    lazy = true,
    opts = {},
  },
  {
    'nvim-neotest/neotest',
    dependencies = {
      {
        'nvim-treesitter/nvim-treesitter', -- Optional, but recommended
        branch = 'main', -- NOTE; not the master branch!
      },
      {
        'fredrikaverpil/neotest-golang', -- Installation
        branch = 'fix/testify-tables',
      },
      dependencies = {
        'leoluz/nvim-dap-go',
        'uga-rosa/utf8.nvim',
      },
    },
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}
      opts.adapters['neotest-golang'] = {
        go_test_args = function()
          return {
            '-v',
            '-count=1',
            '-race',
            '-coverprofile=' .. vim.fn.getcwd() .. '/coverage.out',
            vim.env.GO_TEST_FLAGS or '',
          }
        end,
        dap_go_opts = {
          delve = {
            build_flags = { '-tags=unit,integration,endtoendtest' },
          },
        },
        runner = 'gotestsum',
        gotestsum_args = { '--format=standard-verbose' },
        testify_enabled = true,
        log_level = vim.log.levels.TRACE,

        -- experimental
        dev_notifications = true,
      }
    end,
  },
}
