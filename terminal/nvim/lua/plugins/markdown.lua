return {
  -- {
  --   "epwalsh/obsidian.nvim",
  --   version = "*", -- recommended, use latest release instead of latest commit
  --   lazy = false,
  --   ft = "markdown",
  --   -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
  --   -- event = {
  --   --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
  --   --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/*.md"
  --   --   -- refer to `:h file-pattern` for more examples
  --   --   "BufReadPre path/to/my-vault/*.md",
  --   --   "BufNewFile path/to/my-vault/*.md",
  --   -- },
  --   dependencies = {
  --     -- Required.
  --     "nvim-lua/plenary.nvim",
  --     "ibhagwan/fzf-lua",
  --     -- see below for full list of optional dependencies 👇
  --   },
  --   opts = {
  --     ui = {
  --       enable = false,
  --     },
  --     workspaces = {
  --       {
  --         name = "personal",
  --         path = "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Personal",
  --       },
  --       -- see below for full list of options 👇
  --     },
  --     picker = {
  --       name = "fzf-lua",
  --     },
  --   },
  -- },
  {
    "OXY2DEV/markview.nvim",
    lazy = false,
  },
}
