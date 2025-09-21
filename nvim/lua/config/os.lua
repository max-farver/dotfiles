local M = {}

local uname = (vim.uv or vim.loop).os_uname()
local sys = uname and uname.sysname or vim.fn.has("win32") == 1 and "Windows_NT" or ""

M.is_linux = sys == "Linux"
M.is_macos = sys == "Darwin"
M.is_windows = sys == "Windows_NT"

-- Best-effort WSL detection
M.is_wsl = (function()
  if M.is_linux and vim.fn.has("wsl") == 1 then
    return true
  end
  local release = uname and uname.release or ""
  return M.is_linux and release:lower():find("microsoft") ~= nil
end)()

return M

