-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = { "*_test.go" },
  callback = function(event)
    local tags = {}
    local buf = event.buf
    local pattern = [[^//\s*[+|(go:)]*build\s\+\(.\+\)]]
    local cnt = vim.fn.getbufinfo(buf)[1]["linecount"]
    cnt = math.min(cnt, 10)
    for i = 1, cnt do
      local line = vim.fn.trim(vim.fn.getbufline(buf, i)[1])
      if string.find(line, "package") then
        break
      end
      local t = vim.fn.substitute(line, pattern, [[\1]], "")
      if t ~= line then -- tag found
        t = vim.fn.substitute(t, [[ \+]], ",", "g")
        table.insert(tags, t)
      end
    end
    if #tags > 0 then
      vim.env.GO_TEST_FLAGS = "-tags=" .. table.concat(tags, ",")
    end
  end,
})

-- update buffer if an external program changes it
vim.api.nvim_create_autocmd("FocusGained", {
  desc = "Reload files from disk when we focus vim",
  pattern = "*",
  command = "if getcmdwintype() == '' | checktime | endif",
  group = aug,
})
vim.api.nvim_create_autocmd("BufEnter", {
  desc = "Every time we enter an unmodified buffer, check if it changed on disk",
  pattern = "*",
  command = "if &buftype == '' && !&modified && expand('%') != '' | exec 'checktime ' . expand('<abuf>') | endif",
  group = aug,
})
