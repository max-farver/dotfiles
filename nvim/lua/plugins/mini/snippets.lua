return {
  'nvim-mini/mini.snippets',
  version = '*',
  event = 'VeryLazy',
  opts = function()
    local gen_loader = require('mini.snippets').gen_loader

    return {
      -- Load snippets scoped by language from `snippets/<lang>/` directories.
      snippets = {
        gen_loader.from_lang({ cache = false }),
      },
    }
  end,
  config = function(_, opts)
    local ms = require('mini.snippets')
    ms.setup(opts)
  end,
}
