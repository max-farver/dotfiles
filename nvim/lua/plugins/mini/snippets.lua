return {
  'nvim-mini/mini.snippets',
  version = '*',
  event = 'VeryLazy',
  opts = function()
    return {
      -- keep defaults; we’ll just set up loaders below
    }
  end,
  config = function(_, opts)
    local ms = require('mini.snippets')
    ms.setup(opts)
  end,
}

