local M = {}

local tools = {
  -- linters/formatters
  "shellcheck", "hadolint", "sqlfluff", "terraform", "yamllint",
  -- LSPs (examples; adjust to your nix env)
  "bash-language-server", "pyright-langserver", "ruff", "marksman",
}

local function exists(bin)
  return vim.fn.executable(bin) == 1
end

function M.run()
  local missing = {}
  for _, t in ipairs(tools) do
    if not exists(t) then table.insert(missing, t) end
  end
  if #missing > 0 then
    vim.schedule(function()
      vim.notify("Missing tools: " .. table.concat(missing, ", "), vim.log.levels.WARN)
    end)
  else
    vim.notify("All checked tools present", vim.log.levels.INFO)
  end
end

vim.api.nvim_create_user_command("ToolsCheck", function()
  M.run()
end, { desc = "Check required external tools" })

return M

