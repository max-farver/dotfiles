return {
  'nvim-mini/mini.completion',
  version = '*',
  event = { 'InsertEnter', 'CmdlineEnter' },
  opts = {},
  config = function(_, opts)
    require('mini.completion').setup(opts)
  end,
}

