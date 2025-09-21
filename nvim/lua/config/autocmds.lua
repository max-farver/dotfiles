local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local go_group = augroup("user_go_test_flags", { clear = true })
autocmd("BufEnter", {
  group = go_group,
  pattern = { "*_test.go" },
  callback = function(event)
    local tags = {}
    local buf = event.buf
    local pattern = [[^//\s*[+|(go:)]*build\s\+\(.\+\)]]
    local cnt = vim.fn.getbufinfo(buf)[1].linecount
    cnt = math.min(cnt, 10)
    for i = 1, cnt do
      local line = vim.fn.trim(vim.fn.getbufline(buf, i)[1] or "")
      if line:find("package", 1, true) then
        break
      end
      local t = vim.fn.substitute(line, pattern, [[\1]], "")
      if t ~= line then
        t = vim.fn.substitute(t, [[ \+]], ",", "g")
        table.insert(tags, t)
      end
    end
    if #tags > 0 then
      vim.env.GO_TEST_FLAGS = "-tags=" .. table.concat(tags, ",")
    end
  end,
})

local reload_group = augroup("user_auto_reload", { clear = true })
autocmd("FocusGained", {
  group = reload_group,
  desc = "Reload files from disk when the editor regains focus",
  pattern = "*",
  command = "if getcmdwintype() == '' | checktime | endif",
})
autocmd({ "TermClose", "TermLeave" }, {
  group = reload_group,
  desc = "Reload files when terminal closes/leaves",
  pattern = "*",
  command = "if getcmdwintype() == '' | checktime | endif",
})
autocmd("BufEnter", {
  group = reload_group,
  desc = "Check for external file changes on buffer enter",
  pattern = "*",
  command = "if &buftype == '' && !&modified && expand('%') != '' | execute 'checktime ' .. expand('<abuf>') | endif",
})

-- Yank highlight provided by mini.basics

-- Split equalize on resize provided by mini.basics

-- Restore last cursor location provided by mini.basics

-- Close certain filetypes quickly with q
autocmd("FileType", {
  group = augroup("user_close_with_q", { clear = true }),
  pattern = {
    "PlenaryTestPopup",
    "checkhealth",
    "dbout",
    "gitsigns-blame",
    "grug-far",
    "help",
    "lspinfo",
    "neotest-output",
    "neotest-output-panel",
    "neotest-summary",
    "notify",
    "qf",
    "spectre_panel",
    "startuptime",
    "tsplayground",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.schedule(function()
      vim.keymap.set("n", "q", function()
        vim.cmd("close")
        pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
      end, { buffer = event.buf, silent = true, desc = "Quit buffer" })
    end)
  end,
})

-- Make inline man pages unlisted
autocmd("FileType", {
  group = augroup("user_man_unlisted", { clear = true }),
  pattern = { "man" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
  end,
})

-- Wrap and spell for text-centric filetypes
autocmd("FileType", {
  group = augroup("user_wrap_spell", { clear = true }),
  pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- Fix conceallevel for json-like files
autocmd("FileType", {
  group = augroup("user_json_conceal", { clear = true }),
  pattern = { "json", "jsonc", "json5" },
  callback = function()
    vim.opt_local.conceallevel = 0
  end,
})

-- Auto create directories on save if missing
autocmd("BufWritePre", {
  group = augroup("user_auto_create_dir", { clear = true }),
  callback = function(event)
    if event.match:match("^%w%w+:[\\/][\\/]") then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- Auto enable treesitter for all filetypes
autocmd('FileType', {
  pattern = { 'go' },
  callback = function() vim.treesitter.start() end,
})
