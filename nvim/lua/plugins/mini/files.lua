return {
  'nvim-mini/mini.files',
  version = '*',
  dependencies = {
	"nvim-mini/mini.extra"
  },
  opts = {
	mappings = {
	    close       = 'q',
	    go_in       = 'l',
	    go_in_plus  = '<Right>',
	    go_out      = 'h',
	    go_out_plus = '<Left>',
	    mark_goto   = "'",
	    mark_set    = 'm',
	    reset       = '<BS>',
	    reveal_cwd  = '@',
	    show_help   = 'g?',
	    synchronize = '=',
	    trim_left   = '<',
	    trim_right  = '>',
	  },
      use_as_default_explorer = true,
      permanent_delete = true,
  },
  config = function(_, opts)
    local MiniFiles = require('mini.files')
    MiniFiles.setup(opts)

    -- Add handy buffer-local mappings when mini.files opens
    vim.api.nvim_create_autocmd('User', {
      pattern = 'MiniFilesBufferCreate',
      callback = function(args)
        local buf = args.data.buf_id
        -- Synchronize any pending fs operations (create/rename/move/delete)
        vim.keymap.set('n', 'S', function()
          pcall(function() MiniFiles.synchronize() end)
        end, { buffer = buf, desc = 'mini.files: Synchronize changes' })

        -- Close and sync in one go
        vim.keymap.set('n', 'Q', function()
          pcall(function() MiniFiles.synchronize() end)
          pcall(function() MiniFiles.close() end)
        end, { buffer = buf, desc = 'mini.files: Sync and close' })
      end,
    })
  end,
}
