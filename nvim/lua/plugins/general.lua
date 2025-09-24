local icons = require("config.icons")

return {
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
      "TmuxNavigatorProcessList",
    },
  },

  {
    "otavioschwanck/arrow.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      show_icons = true,
      leader_key = "M",
      buffer_leader_key = "gm",
    },
  },

  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    -- keymaps defined in config/keymaps.lua
  },


  {
    "monaqa/dial.nvim",
    desc = "Increment or decrement common values",
    keys = {
      { "<C-a>",  function() return require("plugins.utils.dial").map(true) end,        expr = true, desc = "Increment",      mode = { "n", "v" } },
      { "<C-x>",  function() return require("plugins.utils.dial").map(false) end,       expr = true, desc = "Decrement",      mode = { "n", "v" } },
      { "g<C-a>", function() return require("plugins.utils.dial").map(true, true) end,  expr = true, desc = "Increment (g)",  mode = { "n", "v" } },
      { "g<C-x>", function() return require("plugins.utils.dial").map(false, true) end, expr = true, desc = "Decrement (g)",  mode = { "n", "v" } },
    },
    opts = require("plugins.utils.dial").opts,
    config = function(_, opts)
      require("plugins.utils.dial").setup(opts)
    end,
  },

  {
    "gbprod/yanky.nvim",
    desc = "Better yank/paste",
    event = "BufReadPost",
    opts = {
      highlight = { timer = 150 },
    },
    -- keymaps defined in config/keymaps.lua
  },

  {
    "stevearc/overseer.nvim",
    cmd = {
      "OverseerRun",
      "OverseerToggle",
      "OverseerTaskAction",
      "OverseerQuickAction",
      "OverseerInfo",
    },
    opts = {},
    -- keymaps defined in config/keymaps.lua
  },

  {
    "ray-x/lsp_signature.nvim",
    event = "InsertEnter",
    version = "0.3.1",
    opts = {},
  },

  {
    "smjonas/inc-rename.nvim",
    cmd = "IncRename",
    opts = {},
  },

  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    opts = function()
      return {
        ensure_installed = {
          "bash",
          "css",
          "dockerfile",
          "git_config",
          "git_rebase",
          "gitattributes",
          "gitcommit",
          "gitignore",
          "go",
          "gomod",
          "gosum",
          "printf",
          "html",
          "hyprlang",
          "javascript",
          "json",
          "json5",
          "jsonc",
          "lua",
          "markdown",
          "markdown_inline",
          "ninja",
          "python",
          "query",
          "regex",
          "rst",
          "sql",
          "terraform",
          "hcl",
          "toml",
          "tsx",
          "typescript",
          "vim",
          "yaml",
        },
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = { enable = true },
        folds = { enable = true },
        auto_install = false,
      }
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    event = "VeryLazy",
    opts = {
      select = {
        enable = true,
        lookahead = true,
        keymaps = {
          ["af"] = "@function.outer",
          ["if"] = "@function.inner",
          ["ac"] = "@class.outer",
          ["ic"] = "@class.inner",
          ["aa"] = "@parameter.outer",
          ["ia"] = "@parameter.inner",
          ["al"] = "@loop.outer",
          ["il"] = "@loop.inner",
          ["aC"] = "@conditional.outer",
          ["iC"] = "@conditional.inner",
          ["ab"] = "@block.outer",
          ["ib"] = "@block.inner",
          ["as"] = "@statement.outer",
        },
      },
      move = {
        enable = true,
        set_jumps = true,
        goto_next_start = {
          ["]f"] = "@function.outer",
          ["]c"] = "@class.outer",
        },
        goto_next_end = {
          ["]F"] = "@function.outer",
          ["]C"] = "@class.outer",
        },
        goto_previous_start = {
          ["[f"] = "@function.outer",
          ["[c"] = "@class.outer",
        },
        goto_previous_end = {
          ["[F"] = "@function.outer",
          ["[C"] = "@class.outer",
        },
      },
      swap = {
        enable = true,
        swap_next = {
          ["]a"] = "@parameter.inner",
        },
        swap_previous = {
          ["[a"] = "@parameter.inner",
        },
      },
    },
  },

  {
    "windwp/nvim-ts-autotag",
    event = "InsertEnter",
    opts = {},
  },
}
