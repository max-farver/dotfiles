return {
  'nvim-mini/mini.basics',
  version = '*',
  config = function(_, opts)
    require('mini.basics').setup(opts)
  end,
}
