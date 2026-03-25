local M = {}

-- Simple project root detection
-- Priority:
-- 1) Active LSP workspace folders (excluding Copilot)
-- 2) Nearest ancestor containing a known marker
-- 3) Fallback to current working directory
function M.get()
  -- 1) LSP roots
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  for _, client in ipairs(clients) do
    if client.name ~= "copilot" and client.config and client.config.root_dir then
      return client.config.root_dir
    end
  end

  -- 2) Marker search upwards
  local markers = {
    ".git",
    "package.json",
    "pyproject.toml",
    "poetry.lock",
    "requirements.txt",
    "go.mod",
    "Cargo.toml",
    "Gemfile",
    "mix.exs",
    "Makefile",
    ".hg",
    ".svn",
    "composer.json",
  }

  local cwd = vim.uv.cwd() or vim.fn.getcwd()
  local path = vim.fs.find(markers, { upward = true, path = vim.api.nvim_buf_get_name(0) })[1]
  if not path then
    -- try from cwd if buffer has no path
    path = vim.fs.find(markers, { upward = true, path = cwd })[1]
  end
  if path then
    local root = vim.fs.dirname(path)
    return root
  end

  -- 3) Fallback
  return cwd
end

return M

