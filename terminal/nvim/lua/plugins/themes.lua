return {
  { "nyoom-engineering/oxocarbon.nvim", name = "oxocarbon" },
  { "catppuccin/nvim", name = "catppuccin" },
  {
    "projekt0n/github-nvim-theme",
    name = "github-theme",
    lazy = false, -- make sure we load this during startup if it is your main colorscheme
    priority = 1000, -- make sure to load this before all the other start plugins
    config = function()
      require("github-theme").setup({
        -- ...
      })

      vim.cmd("colorscheme github_dark")
    end,
  },
  {
    "rebelot/kanagawa.nvim",
    opts = {
      compile = false, -- enable compilation of the colorscheme
      theme = "wave", -- set theme to wave
      background = { -- set background to dark
        dark = "wave",
        light = "lotus",
      },
      overrides = function(colors)
        local theme = colors.theme
        return {
          Pmenu = { fg = theme.ui.shade0, bg = theme.ui.bg_p1 }, -- add `blend = vim.o.pumblend` to enable transparency
          PmenuSel = { fg = "NONE", bg = theme.ui.bg_p2 },
          PmenuSbar = { bg = theme.ui.bg_m1 },
          PmenuThumb = { bg = theme.ui.bg_p2 },
        }
      end,
    },
  },
  { "Mofiqul/dracula.nvim", lazy = false },
}
