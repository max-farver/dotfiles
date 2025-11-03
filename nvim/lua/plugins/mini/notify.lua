return {
  'nvim-mini/mini.notify',
  version = '*',
  lazy = false, -- load early so it can capture startup notifications
  opts = {
    -- We'll keep Mini's defaults but we wrap vim.notify to add sane defaults
  },
  config = function(_, opts)
    local mn = require('mini.notify')
    mn.setup(opts)
    mn.make_notify()
  end,
}
