return {
  -- Enhanced quickfix window with preview, filtering, and more
  {
    "kevinhwang91/nvim-bqf",
    ft = "qf",
    opts = {
      auto_resize_height = true,
      preview = {
        auto_preview = true,
        border = "rounded",
        wrap = true,
      },
    },
    config = function(_, opts)
      require("bqf").setup(opts)
    end,
  },

  -- Faster, nicer quickfix/location list UI & actions
  {
    "stevearc/quicker.nvim",
    event = "VeryLazy",
    opts = {},
    config = function(_, opts)
      require("quicker").setup(opts)
    end,
  },

  -- Quickfix window keymaps
  {
    "quickenhance/qf-keymaps",
    -- not a real plugin; we use this spec to register ft autocmd + maps
    init = function()
      local function open_entry(cmd)
        local lnum = vim.fn.line('.')
        local qf = vim.fn.getqflist({ items = 0 }).items or {}
        local item = qf[lnum]
        if not item or not item.bufnr or item.bufnr == 0 then return end
        local filename = vim.api.nvim_buf_get_name(item.bufnr)
        if filename == '' then return end
        vim.cmd(string.format('%s %s', cmd, vim.fn.fnameescape(filename)))
        local row = item.lnum or 1
        local col = math.max((item.col or 1), 1)
        pcall(vim.api.nvim_win_set_cursor, 0, { row, col })
      end

      local function set_qf_keymaps(buf)
        -- save original list to allow restore after filtering
        if vim.b[buf].qf_original_items == nil then
          local items = vim.fn.getqflist({ items = 0 }).items or {}
          -- make a shallow copy
          local copy = {}
          for i, it in ipairs(items) do copy[i] = it end
          vim.b[buf].qf_original_items = copy
        end

        local map = function(lhs, rhs, desc)
          vim.keymap.set('n', lhs, rhs, { buffer = buf, silent = true, desc = desc })
        end

        map('<CR>', function() open_entry('edit') end, 'Open entry')
        map('s', function() open_entry('split') end, 'Open in split')
        map('v', function() open_entry('vsplit') end, 'Open in vsplit')
        map('t', function() open_entry('tabedit') end, 'Open in tab')
        map('q', function() vim.cmd.cclose() end, 'Close quickfix')

        -- Filter include/exclude by pattern on the entry text
        map('f', function()
          local pat = vim.fn.input('QF filter (include) > ')
          if pat == nil or pat == '' then return end
          local items = vim.fn.getqflist({ items = 0 }).items or {}
          local filtered = {}
          for _, it in ipairs(items) do
            if tostring(it.text or ''):match(pat) then table.insert(filtered, it) end
          end
          vim.fn.setqflist({}, 'r', { items = filtered })
        end, 'Filter include')

        map('F', function()
          local pat = vim.fn.input('QF filter (exclude) > ')
          if pat == nil or pat == '' then return end
          local items = vim.fn.getqflist({ items = 0 }).items or {}
          local filtered = {}
          for _, it in ipairs(items) do
            if not tostring(it.text or ''):match(pat) then table.insert(filtered, it) end
          end
          vim.fn.setqflist({}, 'r', { items = filtered })
        end, 'Filter exclude')

        map('r', function()
          local orig = vim.b.qf_original_items or {}
          if #orig > 0 then
            vim.fn.setqflist({}, 'r', { items = orig })
          end
        end, 'Restore list')
      end

      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'qf',
        group = vim.api.nvim_create_augroup('user_qf_keymaps', { clear = true }),
        callback = function(ev)
          set_qf_keymaps(ev.buf)
        end,
      })
    end,
  },
}
