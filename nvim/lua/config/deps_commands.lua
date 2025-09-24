local M = {}

local function with_mini(fn)
  local ok, deps = pcall(require, 'mini.deps')
  if not ok then
    vim.notify('mini.deps not available', vim.log.levels.ERROR)
    return
  end
  return fn(deps)
end

function M.setup()
  vim.api.nvim_create_user_command('DepsUpdate', function()
    with_mini(function(deps)
      deps.update()
      vim.notify('mini.deps: update complete')
    end)
  end, {})

  vim.api.nvim_create_user_command('DepsLock', function()
    with_mini(function(deps)
      deps.lock()
      vim.notify('mini.deps: lockfile written')
    end)
  end, {})

  vim.api.nvim_create_user_command('DepsClean', function()
    with_mini(function(deps)
      deps.clean()
      vim.notify('mini.deps: clean complete')
    end)
  end, {})
end

return M

