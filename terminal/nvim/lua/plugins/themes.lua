return {
  { "nyoom-engineering/oxocarbon.nvim", name = "oxocarbon" },
  { "catppuccin/nvim", name = "catppuccin" },

  {
    "zaldih/themery.nvim",
    lazy = false,
    config = function()
      require("themery").setup({
        themes = {
          {
            name = "Catppuccin Day",
            colorscheme = "catppuccin-latte",
            before = [[ vim.opt.background = "light" ]],
          },
          {
            name = "Catppuccin Night",
            colorscheme = "catppuccin-frappe",
            before = [[ vim.opt.background = "dark" ]],
          },
          {
            name = "Oxocarbon Day",
            colorscheme = "oxocarbon",
            before = [[ vim.opt.background = "light" ]],
          },
          {
            name = "Oxocarbon Night",
            colorscheme = "oxocarbon",
            before = [[ vim.opt.background = "dark" ]],
          },
        },
      })
    end,
  },
}
