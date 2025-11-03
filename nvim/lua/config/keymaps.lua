local map = function(mode, lhs, rhs, opts)
	opts = opts or {}
	opts.silent = opts.silent ~= false
	vim.keymap.set(mode, lhs, rhs, opts)
end

map({ 'n', 'x' }, '<C-d>', '<C-d>zz', { desc = 'Half page down centered' })
map({ 'n', 'x' }, '<C-u>', '<C-u>zz', { desc = 'Half page up centered' })
map('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear highlight' })
map('n', '<leader>qq', '<cmd>confirm qa<CR>', { desc = 'Quit all' })
map('n', '<leader>ww', '<cmd>w<CR>', { desc = 'Save' })
map('n', '<leader>bd', '<cmd>bd<CR>', { desc = 'Delete buffer' })
map('n', '<leader>bn', '<cmd>bnext<CR>', { desc = 'Next buffer' })
map('n', '<leader>bp', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })
-- mini.files (Explorer)
-- - <leader>fe: Explorer (Root Dir)
-- - <leader>fE: Explorer (cwd)
-- - <leader>e : Alias to <leader>fe
do
	local function open_files(dir)
		local ok, MiniFiles = pcall(require, 'mini.files')
		if not ok then
			vim.notify('mini.files not available', vim.log.levels.WARN)
			return
		end
		MiniFiles.open(dir, true)
	end
	map('n', '<leader>fe', function()
		open_files(require('config.root').get())
	end, { desc = 'Explorer (Root Dir)' })
	map('n', '<leader>fE', function()
		open_files(vim.uv.cwd())
	end, { desc = 'Explorer (cwd)' })
	map('n', '<leader>e', function()
		local file = vim.api.nvim_buf_get_name(0)
		local dir = file ~= '' and vim.fn.fnamemodify(file, ':h') or vim.uv.cwd()
		open_files(dir)
	end, { desc = 'Explorer (Current File Dir)' })
end

-- Save file
map({ 'i', 'x', 'n', 's' }, '<C-s>', '<cmd>w<cr><esc>', { desc = 'Save File' })

-- Window/Split helpers
map('n', '<leader>-', '<C-W>s', { desc = 'Split Window Below', remap = true })
map('n', '<leader>|', '<C-W>v', { desc = 'Split Window Right', remap = true })
map('n', '<leader>wd', '<C-W>c', { desc = 'Delete Window', remap = true })

-- Buffers
map('n', '<S-h>', '<cmd>bprevious<cr>', { desc = 'Prev Buffer' })
map('n', '<S-l>', '<cmd>bnext<cr>', { desc = 'Next Buffer' })
map('n', '[b', '<cmd>bprevious<cr>', { desc = 'Prev Buffer' })
map('n', ']b', '<cmd>bnext<cr>', { desc = 'Next Buffer' })
map('n', '<leader>bb', '<cmd>e #<cr>', { desc = 'Switch to Other Buffer' })
map('n', '<leader>`', '<cmd>e #<cr>', { desc = 'Switch to Other Buffer' })
map('n', '<leader>bo', function()
	local ok, snacks = pcall(require, 'snacks')
	if ok and snacks.bufdelete and snacks.bufdelete.other then
		snacks.bufdelete.other()
	else
		vim.cmd [[silent! %bd|e#|bd#]]
	end
end, { desc = 'Delete Other Buffers' })
map('n', '<leader>bD', '<cmd>:bd<cr>', { desc = 'Delete Buffer and Window' })

-- Better visual indent
map('v', '<', '<gv')
map('v', '>', '>gv')

-- Insert-mode undo break-points
map('i', ',', ',<c-g>u')
map('i', '.', '.<c-g>u')
map('i', ';', ';<c-g>u')


-- Diagnostics navigation
local function diagnostic_goto(next, severity)
	severity = severity and vim.diagnostic.severity[severity] or nil
	return function()
		vim.diagnostic.jump({ count = next and 1 or -1, severity = severity })
	end
end
map('n', ']d', diagnostic_goto(true), { desc = 'Next Diagnostic' })
map('n', '[d', diagnostic_goto(false), { desc = 'Prev Diagnostic' })
map('n', ']e', diagnostic_goto(true, 'ERROR'), { desc = 'Next Error' })
map('n', '[e', diagnostic_goto(false, 'ERROR'), { desc = 'Prev Error' })
map('n', ']w', diagnostic_goto(true, 'WARN'), { desc = 'Next Warning' })
map('n', '[w', diagnostic_goto(false, 'WARN'), { desc = 'Prev Warning' })

-- Quickfix / Location list toggles
map('n', '<leader>xl', function()
	local ok, err = pcall(vim.fn.getloclist(0, { winid = 0 }).winid ~= 0 and vim.cmd.lclose or vim.cmd.lopen)
	if not ok and err then
		vim.notify(err, vim.log.levels.ERROR)
	end
end, { desc = 'Location List' })
map('n', '<leader>xq', function()
	local ok, err = pcall(vim.fn.getqflist({ winid = 0 }).winid ~= 0 and vim.cmd.cclose or vim.cmd.copen)
	if not ok and err then
		vim.notify(err, vim.log.levels.ERROR)
	end
end, { desc = 'Quickfix List' })

-- Lazy, New File, Keywordprg, Redraw
map('n', '<leader>l', '<cmd>Lazy<cr>', { desc = 'Lazy' })
map('n', '<leader>fn', '<cmd>enew<cr>', { desc = 'New File' })
map('n', '<leader>K', '<cmd>norm! K<cr>', { desc = 'Keywordprg' })
map('n', '<leader>ur', '<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>',
	{ desc = 'Redraw / Clear hlsearch / Diff Update' })
map('n', '<leader>ui', vim.show_pos, { desc = 'Inspect Pos' })
map('n', '<leader>uI', function()
	vim.treesitter.inspect_tree()
	vim.api.nvim_input 'I'
end, { desc = 'Inspect Tree' })

-- Code (LSP) helpers
map('n', '<leader>cli', '<cmd>LspInfo<cr>', { desc = 'LSP Info' })
map('n', '<leader>clr', '<cmd>LspRestart<cr>', { desc = 'LSP Restart' })
map({ 'n', 'x' }, '<leader>ca', function()
	if vim.lsp.buf.code_action then
		vim.lsp.buf.code_action()
	end
end, { desc = 'Code Action' })
map('n', 'gd', function()
	vim.lsp.buf.definition()
end, { desc = 'Go to Definition', remap = true })

-- LSP references/impl/type-def/code-actions via mini.pick
map('n', 'grr', function()
	local ok, pick = pcall(require, 'mini.pick')
	if ok and pick.builtin and pick.builtin.lsp_references then
		pick.builtin.lsp_references()
		return
	end
	vim.lsp.buf.references()
end, { desc = 'LSP References' })

map('n', 'gri', function()
	local ok, pick = pcall(require, 'mini.pick')
	if ok and pick.builtin and pick.builtin.lsp_implementations then
		pick.builtin.lsp_implementations()
		return
	end
	vim.lsp.buf.implementation()
end, { desc = 'LSP Implementations' })

map('n', 'grt', function()
	vim.lsp.buf.type_definition()
end, { desc = 'Go to Type Definition' })

map('n', 'gra', function()
	local ok, pick = pcall(require, 'mini.pick')
	if ok and pick.builtin and pick.builtin.lsp_code_actions then
		pick.builtin.lsp_code_actions()
		return
	end
	vim.lsp.buf.code_action()
end, { desc = 'LSP Code Actions' })

-- Completion / Snippet confirm + navigation
-- - <Tab> confirms current completion item (if popup visible)
-- - <CR> confirms and inserts a newline (if popup visible)
-- - <Down>/<Up> or <C-n>/<C-p> navigate completion items
do
	local pumvisible = function()
		return vim.fn.pumvisible() == 1
	end

	local function try_snippet_jump_forward()
		local ok, ms = pcall(require, 'mini.snippets')
		if not ok or not ms then
			return false
		end
		local jumped_ok, res = pcall(ms.jump, 1)
		return jumped_ok and res == true
	end

	local function try_snippet_jump_backward()
		local ok, ms = pcall(require, 'mini.snippets')
		if not ok or not ms then
			return false
		end
		local jumped_ok, res = pcall(ms.jump, -1)
		return jumped_ok and res == true
	end

	-- Tab: confirm current selection when popup menu is visible, otherwise insert tab
	map('i', '<Tab>', function()
		if try_snippet_jump_forward() then
			return ''
		end
		if pumvisible() then
			return '<C-y>'
		end
		return '\t'
	end, { expr = true, desc = 'Jump snippet / confirm completion / Tab' })

	-- Shift-Tab: jump to previous snippet field; else navigate previous completion; else insert Tab
	map('i', '<S-Tab>', function()
		if try_snippet_jump_backward() then
			return ''
		end
		if pumvisible() then
			return '<C-p>'
		end
		return '\t'
	end, { expr = true, desc = 'Jump snippet back / previous completion / Tab' })

	-- Enter: do NOT accept completion; just newline (cancel popup if visible)
	map('i', '<CR>', function()
		if pumvisible() then
			return '<C-e><CR>'
		end
		return '\n'
	end, { expr = true, desc = 'Newline (no completion confirm)' })

	-- Navigate with arrows when popup is visible
	map('i', '<Down>', function()
		if pumvisible() then
			return '<C-n>'
		end
		return '<Down>'
	end, { expr = true, desc = 'Next completion item' })

	map('i', '<Up>', function()
		if pumvisible() then
			return '<C-p>'
		end
		return '<Up>'
	end, { expr = true, desc = 'Prev completion item' })

	-- Ensure Ctrl-n / Ctrl-p navigate items (even if some plugin remaps them)
	map('i', '<C-n>', function()
		if pumvisible() then
			return '<C-n>'
		end
		return '<C-n>'
	end, { expr = true, desc = 'Next completion item' })

	map('i', '<C-p>', function()
		if pumvisible() then
			return '<C-p>'
		end
		return '<C-p>'
	end, { expr = true, desc = 'Prev completion item' })

	-- Keep arrows for cmdline history; use <C-n>/<C-p> for completion
end

-- Flash (jump/search)
map({ 'n', 'x', 'o' }, 's', function()
	local ok, f = pcall(require, 'flash')
	if ok then
		f.jump()
	end
end, { desc = 'Flash' })
map({ 'n', 'x', 'o' }, 'S', function()
	local ok, f = pcall(require, 'flash')
	if ok then
		f.treesitter()
	end
end, { desc = 'Flash Treesitter' })
map('o', 'r', function()
	local ok, f = pcall(require, 'flash')
	if ok then
		f.remote()
	end
end, { desc = 'Remote Flash' })
map({ 'o', 'x' }, 'R', function()
	local ok, f = pcall(require, 'flash')
	if ok then
		f.treesitter_search()
	end
end, { desc = 'Treesitter Search' })
map('c', '<c-s>', function()
	local ok, f = pcall(require, 'flash')
	if ok then
		f.toggle()
	end
end, { desc = 'Toggle Flash Search' })

-- Tmux Navigator
map('n', '<c-Left>', '<cmd>TmuxNavigateLeft<cr>', { desc = 'Tmux Left' })
map('n', '<c-h>', '<cmd>TmuxNavigateLeft<cr>', { desc = 'Tmux Left' })
map('n', '<c-Down>', '<cmd>TmuxNavigateDown<cr>', { desc = 'Tmux Down' })
map('n', '<c-j>', '<cmd>TmuxNavigateDown<cr>', { desc = 'Tmux Down' })
map('n', '<c-Up>', '<cmd>TmuxNavigateUp<cr>', { desc = 'Tmux Up' })
map('n', '<c-k>', '<cmd>TmuxNavigateUp<cr>', { desc = 'Tmux Up' })
map('n', '<c-Right>', '<cmd>TmuxNavigateRight<cr>', { desc = 'Tmux Right' })
map('n', '<c-l>', '<cmd>TmuxNavigateRight<cr>', { desc = 'Tmux Right' })
map('n', '<c-\\>', '<cmd>TmuxNavigatePrevious<cr>', { desc = 'Tmux Previous' })

-- Yanky
map({ 'n', 'x' }, 'y', '<Plug>(YankyYank)', { desc = 'Yank Text' })
map({ 'n', 'x' }, 'p', '<Plug>(YankyPutAfter)', { desc = 'Put After' })
map({ 'n', 'x' }, 'P', '<Plug>(YankyPutBefore)', { desc = 'Put Before' })
map({ 'n', 'x' }, 'gp', '<Plug>(YankyGPutAfter)', { desc = 'GPut After' })
map({ 'n', 'x' }, 'gP', '<Plug>(YankyGPutBefore)', { desc = 'GPut Before' })
map('n', '[y', '<Plug>(YankyCycleForward)', { desc = 'Yank Cycle Fwd' })
map('n', ']y', '<Plug>(YankyCycleBackward)', { desc = 'Yank Cycle Back' })
map('n', ']p', '<Plug>(YankyPutIndentAfterLinewise)', { desc = 'Put Indented After (Linewise)' })
map('n', '[p', '<Plug>(YankyPutIndentBeforeLinewise)', { desc = 'Put Indented Before (Linewise)' })
map('n', ']P', '<Plug>(YankyPutIndentAfterLinewise)', { desc = 'Put Indented After (Linewise)' })
map('n', '[P', '<Plug>(YankyPutIndentBeforeLinewise)', { desc = 'Put Indented Before (Linewise)' })
map('n', '>p', '<Plug>(YankyPutIndentAfterShiftRight)', { desc = 'Put and Indent Right' })
map('n', '<p', '<Plug>(YankyPutIndentAfterShiftLeft)', { desc = 'Put and Indent Left' })
map('n', '>P', '<Plug>(YankyPutIndentBeforeShiftRight)', { desc = 'Put Before and Indent Right' })
map('n', '<P', '<Plug>(YankyPutIndentBeforeShiftLeft)', { desc = 'Put Before and Indent Left' })
map('n', '=p', '<Plug>(YankyPutAfterFilter)', { desc = 'Put After Filter' })
map('n', '=P', '<Plug>(YankyPutBeforeFilter)', { desc = 'Put Before Filter' })
map({ 'n', 'x' }, '<leader>p', function()
	local ok, pick = pcall(require, 'mini.pick')
	if ok and pick.builtin and pick.builtin.yanky then
		pick.builtin.yanky()
		return
	end
	vim.cmd [[YankyRingHistory]]
end, { desc = 'Open Yank History' })

-- Overseer
map('n', '<leader>o', '<nop>', { desc = 'Overseer' })
map('n', '<leader>ot', '<cmd>OverseerToggle<cr>', { desc = 'Overseer Toggle' })
map('n', '<leader>oa', '<cmd>OverseerTaskAction<cr>', { desc = 'Overseer Task Action' })
map('n', '<leader>or', '<cmd>OverseerRun<cr>', { desc = 'Overseer Run' })

-- Grug-Far
map('n', '<leader>sg', function()
	local ok, g = pcall(require, 'grug-far')
	if ok then
		g.open()
	end
end, { desc = 'Search (grug-far)' })

-- SQL: Dadbod UI
map('n', '<leader>D', '<cmd>DBUIToggle<CR>', { desc = 'Toggle DBUI' })

-- DAP core
map('n', '<leader>dB', function()
	require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
end, { desc = 'Breakpoint Condition' })
map('n', '<leader>db', function()
	require('dap').toggle_breakpoint()
end, { desc = 'Toggle Breakpoint' })
map('n', '<leader>dl', function()
	require('dap').run_last()
end, { desc = 'Run Last' })
map('n', '<leader>ds', function()
	require('dap').session()
end, { desc = 'Session' })
map('n', '<leader>dt', function()
	require('dap').terminate()
end, { desc = 'Terminate' })

-- Debugmaster toggle
map('n', '<leader>dd', function()
	local ok, dm = pcall(require, 'debugmaster')
	if ok then
		dm.mode.toggle()
	end
end, { desc = 'Toggle Debug Mode' })

-- Neotest
map('n', '<leader>t', '<nop>', { desc = '+test' })
map('n', '<leader>tt', function()
	require('neotest').run.run(vim.fn.expand '%')
end, { desc = 'Run File' })
map('n', '<leader>tT', function()
	require('neotest').run.run(vim.uv.cwd())
end, { desc = 'Run All Files' })
map('n', '<leader>tr', function()
	require('neotest').run.run()
end, { desc = 'Run Nearest' })
map('n', '<leader>tl', function()
	require('neotest').run.run_last()
end, { desc = 'Run Last' })
map('n', '<leader>ts', function()
	require('neotest').summary.toggle()
end, { desc = 'Toggle Summary' })
map('n', '<leader>to', function()
	require('neotest').output.open { enter = true, auto_close = true }
end, { desc = 'Show Output' })
map('n', '<leader>tO', function()
	require('neotest').output_panel.toggle()
end, { desc = 'Toggle Output Panel' })
map('n', '<leader>tS', function()
	require('neotest').run.stop()
end, { desc = 'Stop Tests' })
map('n', '<leader>tw', function()
	require('neotest').watch.toggle(vim.fn.expand '%')
end, { desc = 'Toggle Watch' })
map('n', '<leader>td', function()
	require('neotest').run.run { strategy = 'dap' }
end, { desc = 'Debug Nearest' })

-- Snacks toggles (register after lazy plugins load)
vim.api.nvim_create_autocmd('User', {
	pattern = 'VeryLazy',
	callback = function()
		local ok, Snacks = pcall(require, 'snacks')
		if not ok then
			return
		end
		Snacks.toggle.option('spell', { name = 'Spelling' }):map '<leader>us'
		Snacks.toggle.option('wrap', { name = 'Wrap' }):map '<leader>uw'
		Snacks.toggle.line_number():map '<leader>ul'
		Snacks.toggle.option('relativenumber', { name = 'Relative Number' }):map '<leader>uL'
		Snacks.toggle.diagnostics():map '<leader>ud'
		Snacks.toggle.treesitter():map '<leader>uT'
		Snacks.toggle.option('conceallevel',
			{ off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2, name = 'Conceal Level' })
			:map '<leader>uc'
		Snacks.toggle.option('showtabline',
			{ off = 0, on = vim.o.showtabline > 0 and vim.o.showtabline or 2, name = 'Tabline' }):map '<leader>uA'
		Snacks.toggle.option('background', { off = 'light', on = 'dark', name = 'Dark Background' }):map '<leader>ub'
		Snacks.toggle.dim():map '<leader>uD'
		Snacks.toggle.animate():map '<leader>ua'
		Snacks.toggle.indent():map '<leader>ug'
		Snacks.toggle.scroll():map '<leader>uS'
		Snacks.toggle.profiler():map '<leader>dpp'
		Snacks.toggle.profiler_highlights():map '<leader>dph'
		if vim.lsp.inlay_hint then
			Snacks.toggle.inlay_hints():map '<leader>uh'
		end
		Snacks.toggle.new({
			id = "autoformat",
			name = "Autoformat",
			get = function()
				return not vim.g.disable_autoformat
			end,
			set = function(state)
				vim.g.disable_autoformat = not state
			end
		}):map '<leader>uf'
	end,
})

map('n', '<leader>uF', function()
	if vim.b.disable_autoformat then
		vim.b.disable_autoformat = false
	else
		vim.cmd('FormatDisable!')
	end
end, { desc = 'Toggle Buffer Autoformat' })

-- Tabs suite
map('n', '<leader><tab>l', '<cmd>tablast<cr>', { desc = 'Last Tab' })
map('n', '<leader><tab>o', '<cmd>tabonly<cr>', { desc = 'Close Other Tabs' })
map('n', '<leader><tab>f', '<cmd>tabfirst<cr>', { desc = 'First Tab' })
map('n', '<leader><tab><tab>', '<cmd>tabnew<cr>', { desc = 'New Tab' })
map('n', '<leader><tab>]', '<cmd>tabnext<cr>', { desc = 'Next Tab' })
map('n', '<leader><tab>d', '<cmd>tabclose<cr>', { desc = 'Close Tab' })
map('n', '<leader><tab>[', '<cmd>tabprevious<cr>', { desc = 'Previous Tab' })

-- Gitsigns
do
	local function with_gitsigns(fn)
		return function(...)
			local ok, gs = pcall(require, 'gitsigns')
			if not ok then
				vim.notify('gitsigns not available', vim.log.levels.WARN)
				return
			end
			if type(gs[fn]) == 'function' then
				gs[fn](...)
			end
		end
	end

	-- group header
	map('n', '<leader>g', '<nop>', { desc = '+git' })

	-- hunk actions
	map('n', '<leader>gs', with_gitsigns 'stage_hunk', { desc = 'Stage Hunk' })
	map('n', '<leader>gr', with_gitsigns 'reset_hunk', { desc = 'Reset Hunk' })
	map('v', '<leader>gs', with_gitsigns 'stage_hunk', { desc = 'Stage Hunk' })
	map('v', '<leader>gr', with_gitsigns 'reset_hunk', { desc = 'Reset Hunk' })
	map('n', '<leader>gu', with_gitsigns 'undo_stage_hunk', { desc = 'Undo Stage Hunk' })
	map('n', '<leader>gS', with_gitsigns 'stage_buffer', { desc = 'Stage Buffer' })
	map('n', '<leader>gR', with_gitsigns 'reset_buffer', { desc = 'Reset Buffer' })
	map('n', '<leader>gp', with_gitsigns 'preview_hunk', { desc = 'Preview Hunk' })

	-- navigation
	map('n', '<leader>gj', with_gitsigns 'next_hunk', { desc = 'Next Hunk' })
	map('n', '<leader>gk', with_gitsigns 'prev_hunk', { desc = 'Prev Hunk' })

	-- toggles and info
	map('n', '<leader>gb', with_gitsigns 'blame_line', { desc = 'Blame Line' })
	map('n', '<leader>gB', with_gitsigns 'toggle_current_line_blame', { desc = 'Toggle Blame' })
	map('n', '<leader>gt', with_gitsigns 'toggle_deleted', { desc = 'Toggle Deleted' })

	-- diff
	map('n', '<leader>gd', with_gitsigns 'diffthis', { desc = 'Diff This' })
	map('n', '<leader>gD', function()
		with_gitsigns 'diffthis' '~'
	end, { desc = 'Diff This (~)' })

	-- select hunk
	map({ 'n', 'v' }, '<leader>gh', with_gitsigns 'select_hunk', { desc = 'Select Hunk' })
end

-- Extra Pickers (mini.pick only)
do
	local function with_pick(fn, opts)
		return function()
			local pick_ok, pick = pcall(require, 'mini.pick')
			local extra_ok, extra = pcall(require, 'mini.extra')

			if not pick_ok then
				vim.notify('mini.pick not available', vim.log.levels.WARN)
				return
			end

			-- Prefer builtin pickers
			if pick.builtin and type(pick.builtin[fn]) == 'function' then
				pick.builtin[fn](opts or {})
				return
			end

			-- Fallback to mini.extra pickers
			if extra_ok and extra and extra.pickers and type(extra.pickers[fn]) == 'function' then
				extra.pickers[fn](opts or {})
				return
			end

			vim.notify("Picker '" .. tostring(fn) .. "' not available", vim.log.levels.WARN)
		end
	end

	local root = function()
		local ok, r = pcall(require, 'config.root')
		return (ok and r.get()) or (vim.uv.cwd() or vim.fn.getcwd())
	end

	-- Files
	map('n', '<leader>ff', with_pick('files', { cwd = root() }), { desc = 'Find Files (Root Dir)' })
	map('n', '<leader><leader>', '<leader>ff', { desc = 'Find Files (Root Dir)', remap = true })
	map('n', '<leader>fF', with_pick('files', { cwd = vim.uv.cwd() }), { desc = 'Find Files (cwd)' })
	map('n', '<leader>fb', with_pick 'buffers', { desc = 'Buffers' })
	map('n', '<leader>fo', with_pick 'oldfiles', { desc = 'Recent Files' })
	map('n', '<leader>fr', with_pick('oldfiles', { cwd = root() }), { desc = 'Recent Files (Root Dir)' })
	map('n', '<leader>fR', with_pick 'oldfiles', { desc = 'Recent Files (global)' })
	map('n', '<leader>fg', with_pick('files', { cwd = root() }), { desc = 'Find Files (Root Dir)' })

	-- Search
	map({ 'n', 'x' }, '<leader>sw', function()
		local word
		if vim.fn.mode():find '[vV\22]' then
			word = vim.fn.getreg '*'
		else
			word = vim.fn.expand '<cword>'
		end
		require('mini.pick').builtin.grep { pattern = word, cwd = root() }
	end, { desc = 'Search Word (Root Dir)' })
	map('n', '<leader>/', with_pick('grep_live', { cwd = root() }), { desc = 'Search (Live Grep, Root)' })
	map('n', '<leader>?', with_pick('grep_live', { cwd = vim.uv.cwd() }), { desc = 'Search (Live Grep, cwd)' })
	map('n', '<leader>sl', with_pick 'lines', { desc = 'Search Lines (buffer)' })
	map('n', '<leader>sm', with_pick 'marks', { desc = 'Search Marks' })
	map('n', '<leader>sh', with_pick 'help', { desc = 'Help Tags' })

	-- Commands and keymaps pickers (mini.pick)
	map('n', '<leader>sC', with_pick 'commands', { desc = 'Search Commands' })
	map('n', '<leader>sk', with_pick 'keymaps', { desc = 'Search Keymaps' })
	map('n', '<leader>sd', with_pick 'diagnostics', { desc = 'Search Diagnostics' })

	-- LSP pickers (mini.pick custom)
	map('n', '<leader>sr', with_pick 'lsp_references', { desc = 'LSP References' })
	map('n', '<leader>si', with_pick 'lsp_implementations', { desc = 'LSP Implementations' })
	map('n', '<leader>st', with_pick 'lsp_type_definitions', { desc = 'LSP Type Definitions' })
	map('n', '<leader>sA', with_pick 'lsp_code_actions', { desc = 'LSP Code Actions' })

	-- Git pickers (mini.pick custom)
	map('n', '<leader>sS', with_pick 'git_status', { desc = 'Git Status' })
	map('n', '<leader>sB', with_pick 'git_branches', { desc = 'Git Branches' })
	map('n', '<leader>sT', with_pick 'git_stash', { desc = 'Git Stash' })
	map('n', '<leader>sF', with_pick 'git_log_file', { desc = 'Git File Commits' })
	map('n', '<leader>sG', with_pick 'git_log', { desc = 'Git Log' })

	-- (LSP quickfix fallbacks no longer needed; custom mini.pick LSP pickers are mapped above)
end

-- Git Browse (remote URL) via gitlinker
do
	local function gl_action(action)
		return function()
			local ok, gitlinker = pcall(require, 'gitlinker')
			if not ok then
				vim.notify('gitlinker not available', vim.log.levels.WARN)
				return
			end
			local actions_ok, actions = pcall(require, 'gitlinker.actions')
			if not actions_ok then
				vim.notify('gitlinker.actions not available', vim.log.levels.WARN)
				return
			end
			local cb = (action == 'open') and actions.open_in_browser or actions.copy_to_clipboard
			-- Detect the current mode: 'v' for visual/visual-line, 'n' for normal
			local mode = vim.fn.mode():match('[vV\22]') and 'v' or 'n'
			gitlinker.get_buf_range_url(mode, { action_callback = cb })
		end
	end

	-- open remote in browser
	map({ 'n', 'x' }, '<leader>go', gl_action('open'), { desc = 'Git Browse (open)' })

	-- copy remote URL to clipboard
	map({ 'n', 'x' }, '<leader>gy', gl_action('copy'), { desc = 'Git Browse (copy)' })
end
