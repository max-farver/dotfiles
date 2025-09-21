return {
  'nvim-mini/mini.pick',
  version = '*',
  opts = {},
  config = function(_, opts)
    local pick = require('mini.pick')
    pick.setup(opts)
    pick.builtin = pick.builtin or {}

    local uv = vim.uv or vim.loop
    local function pesc(s)
      -- pattern-escape string without relying on vim.pesc (for older Neovim)
      return (s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
    end

    -- Helper to present a simple list using mini.pick when possible,
    -- otherwise fallback to vim.ui.select
    local function choose_list(title, items, fmt, on_choose)
      fmt = fmt or function(it) return it.label or it.text or tostring(it) end
      local ok = pcall(function()
        -- Try to use a simple picker via mini.pick if supported
        -- prefer mini.pick UI if a generic "select" exists in this version
        if pick.builtin and type(pick.builtin.select) == 'function' then
          return pick.builtin.select(items, { prompt = title, format_item = fmt, on_choose = on_choose })
        end
        -- otherwise, fallthrough to fallback
        error('no generic mini.pick select')
      end)
      if not ok then
        vim.ui.select(items, { prompt = title, format_item = fmt }, function(choice)
          if choice then on_choose(choice) end
        end)
      end
    end

    local function syslines(cmd, cwd)
      if vim.system then
        local res = vim.system(cmd, { cwd = cwd, text = true }):wait()
        local out = (res.stdout or ''):gsub('\r', '')
        local t = {}
        for line in out:gmatch('([^\n]+)') do table.insert(t, line) end
        return t
      else
        local cmd_str
        if type(cmd) == 'table' then
          if cwd and cmd[1] == 'git' then
            local t = { 'git', '-C', cwd }
            for i = 2, #cmd do table.insert(t, cmd[i]) end
            cmd_str = table.concat(t, ' ')
          else
            cmd_str = table.concat(cmd, ' ')
          end
        else
          cmd_str = tostring(cmd)
        end
        local out = table.concat(vim.fn.systemlist(cmd_str) or {}, "\n")
        local t = {}
        for line in out:gmatch('([^\n]+)') do table.insert(t, line) end
        return t
      end
    end

    local function git_root()
      if vim.system then
        local res = vim.system({ 'git', 'rev-parse', '--show-toplevel' }, { text = true }):wait()
        if res.code == 0 then
          return (res.stdout or ''):gsub('%s+$', '')
        end
      else
        local out = vim.fn.systemlist('git rev-parse --show-toplevel')
        if vim.v.shell_error == 0 and out and out[1] then
          return (out[1] or ''):gsub('%s+$', '')
        end
      end
      return (uv and uv.cwd()) or vim.fn.getcwd()
    end

    -- Git: branches
    pick.builtin.git_branches = function()
      local root = git_root()
      local lines = syslines({ 'git', 'branch', '--all', '--format=%(refname:short)' }, root)
      local items = {}
      for _, l in ipairs(lines) do
        if l ~= '' then table.insert(items, { label = l }) end
      end
      choose_list('Git Branches', items, nil, function(it)
        if not it then return end
        vim.system({ 'git', 'checkout', it.label }, { cwd = root }):wait()
        vim.notify('Checked out ' .. it.label)
      end)
    end

    -- Git: status
    pick.builtin.git_status = function()
      local root = git_root()
      local lines = syslines({ 'git', 'status', '--porcelain' }, root)
      local items = {}
      for _, l in ipairs(lines) do
        local status, path = l:match('^(..)%s+(.*)')
        if path then table.insert(items, { status = status, path = path, label = status .. ' ' .. path }) end
      end
      choose_list('Git Status', items, nil, function(it)
        if not it then return end
        vim.cmd('edit ' .. vim.fn.fnameescape(root .. '/' .. it.path))
      end)
    end

    -- Git: stash list
    pick.builtin.git_stash = function()
      local root = git_root()
      local lines = syslines({ 'git', 'stash', 'list', '--format=%gd %h %s' }, root)
      local items = {}
      for _, l in ipairs(lines) do table.insert(items, { label = l }) end
      choose_list('Git Stash', items, nil, function(it)
        if not it then return end
        local name = it.label:match('^(stash@%b{})') or it.label:match('^(%S+)')
        if not name then return end
        -- Show stash in a scratch buffer
        local res = vim.system({ 'git', 'stash', 'show', '-p', name }, { cwd = root, text = true }):wait()
        local buf = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(res.stdout or '', '\n'))
        vim.bo[buf].buftype = 'nofile'
        vim.bo[buf].bufhidden = 'wipe'
        vim.bo[buf].filetype = 'git'
        vim.cmd('vsplit')
        vim.api.nvim_win_set_buf(0, buf)
      end)
    end

    -- Git: repo log
    pick.builtin.git_log = function()
      local root = git_root()
      local lines = syslines({ 'git', 'log', '--oneline', '--decorate', '--graph', '--max-count=200' }, root)
      local items = {}
      for _, l in ipairs(lines) do table.insert(items, { label = l, sha = l:match('%x+') }) end
      choose_list('Git Log', items, nil, function(it)
        if not it or not it.sha then return end
        local res = vim.system({ 'git', 'show', '--stat', it.sha }, { cwd = root, text = true }):wait()
        local buf = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(res.stdout or '', '\n'))
        vim.bo[buf].buftype = 'nofile'
        vim.bo[buf].bufhidden = 'wipe'
        vim.bo[buf].filetype = 'git'
        vim.cmd('vsplit')
        vim.api.nvim_win_set_buf(0, buf)
      end)
    end

    -- Git: current file log
    pick.builtin.git_log_file = function()
      local root = git_root()
      local file = vim.fn.expand('%:p')
      local rel = file:gsub('^' .. pesc(root) .. '/?', '')
      local lines = syslines({ 'git', 'log', '--oneline', '--decorate', '--', rel }, root)
      local items = {}
      for _, l in ipairs(lines) do table.insert(items, { label = l, sha = l:match('%x+') }) end
      choose_list('Git File Log', items, nil, function(it)
        if not it or not it.sha then return end
        local res = vim.system({ 'git', 'show', '--stat', it.sha, '--', rel }, { cwd = root, text = true }):wait()
        local buf = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(res.stdout or '', '\n'))
        vim.bo[buf].buftype = 'nofile'
        vim.bo[buf].bufhidden = 'wipe'
        vim.bo[buf].filetype = 'git'
        vim.cmd('vsplit')
        vim.api.nvim_win_set_buf(0, buf)
      end)
    end

    -- LSP Utilities
    local function lsp_gather(method, params, cb)
      local client = vim.lsp.get_active_clients({ bufnr = vim.api.nvim_get_current_buf() })[1]
      if not client then return vim.notify('No LSP client attached', vim.log.levels.WARN) end
      vim.lsp.buf_request(0, method, params, function(err, result)
        if err then
          vim.notify('LSP error: ' .. (err.message or tostring(err)), vim.log.levels.ERROR)
          return
        end
        cb(result or {})
      end)
    end

    local function cur_pos_params()
      local pos = vim.lsp.util.make_position_params(0, 'utf-16')
      return pos
    end

    local function pick_locations(title, locs)
      local items = {}
      for _, loc in ipairs(locs) do
        local uri = loc.uri or (loc.targetUri)
        local range = loc.range or (loc.targetRange)
        local fname = vim.uri_to_fname(uri)
        local row = (range.start.line or 0) + 1
        local col = (range.start.character or 0) + 1
        table.insert(items, { label = string.format('%s:%d:%d', fname, row, col), uri = uri, range = range })
      end
      choose_list(title, items, nil, function(it)
        if not it then return end
        local fname = vim.uri_to_fname(it.uri)
        vim.cmd('edit ' .. vim.fn.fnameescape(fname))
        local row = (it.range.start.line or 0) + 1
        local col = (it.range.start.character or 0) + 1
        pcall(vim.api.nvim_win_set_cursor, 0, { row, col })
      end)
    end

    pick.builtin.lsp_references = function()
      local params = vim.lsp.util.make_position_params(0, 'utf-16')
      params.context = { includeDeclaration = true }
      lsp_gather('textDocument/references', params, function(res)
        pick_locations('LSP References', res)
      end)
    end

    pick.builtin.lsp_implementations = function()
      lsp_gather('textDocument/implementation', cur_pos_params(), function(res)
        pick_locations('LSP Implementations', res)
      end)
    end

    pick.builtin.lsp_type_definitions = function()
      lsp_gather('textDocument/typeDefinition', cur_pos_params(), function(res)
        pick_locations('LSP Type Definitions', res)
      end)
    end

    pick.builtin.lsp_code_actions = function()
      -- Defer to the built-in LSP UI for code actions
      vim.lsp.buf.code_action()
    end
  end,
}
