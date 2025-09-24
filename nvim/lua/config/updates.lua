-- Simple updates provider to mimic lazy.status
local M = {
  _pending = 0,
  _last_check = 0,
}

local function with_mini(cb)
  local ok, deps = pcall(require, 'mini.deps')
  if not ok then return end
  return cb(deps)
end

function M.check_now()
  return with_mini(function(deps)
    local ok, info = pcall(deps.status)
    if not ok or type(info) ~= 'table' then return 0 end
    -- info.outdated expected as a list of plugins with updates
    local count = 0
    if info.outdated and type(info.outdated) == 'table' then
      for _ in pairs(info.outdated) do count = count + 1 end
    end
    M._pending = count
    M._last_check = vim.uv and (vim.uv.now() or 0) or os.time()
    return count
  end) or 0
end

function M.get_updates()
  return M._pending or 0
end

function M.has_updates()
  return (M._pending or 0) > 0
end

function M.setup_autocheck()
  -- Check once after startup and then every few hours
  local function schedule()
    vim.defer_fn(function()
      pcall(M.check_now)
      schedule()
    end, 3 * 60 * 60 * 1000) -- 3h
  end
  vim.api.nvim_create_autocmd('User', {
    pattern = 'VeryLazy',
    once = true,
    callback = function()
      pcall(M.check_now)
      schedule()
    end,
  })
end

return M

