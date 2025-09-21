return {
  'nvim-mini/mini.animate',
  version = '*',
  opts = {
    scroll = { enable = false },
  },
  config = function(_, opts)
    require('mini.animate').setup(opts)
  end,
}
