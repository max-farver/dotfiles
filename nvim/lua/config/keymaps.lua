local keymap = function(mode, lhs, rhs, opts)
	opts = opts or {}
	opts.silent = opts.silent ~= false
	vim.keymap.set(mode, lhs, rhs, opts)
end

keymap({ 'n', 'x' }, '<C-d>', '<C-d>zz', { desc = 'Half page down centered' })
keymap({ 'n', 'x' }, '<C-u>', '<C-u>zz', { desc = 'Half page up centered' })
keymap('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear highlight' })
keymap('n', '<leader>qq', '<cmd>confirm qa<CR>', { desc = 'Quit all' })
keymap('n', '<leader>ww', '<cmd>w<CR>', { desc = 'Save' })
keymap('n', '<leader>bd', '<cmd>bd<CR>', { desc = 'Delete buffer' })
keymap('n', '<leader>bn', '<cmd>bnext<CR>', { desc = 'Next buffer' })
keymap('n', '<leader>bp', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })
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
	keymap('n', '<leader>fe', function()
		open_files(require('config.root').get())
	end, { desc = 'Explorer (Root Dir)' })
	keymap('n', '<leader>fE', function()
		open_files(vim.uv.cwd())
	end, { desc = 'Explorer (cwd)' })
	keymap('n', '<leader>e', '<leader>fe', { desc = 'Explorer (Root Dir)', remap = true })
end

-- Save file
keymap({ 'i', 'x', 'n', 's' }, '<C-s>', '<cmd>w<cr><esc>', { desc = 'Save File' })

-- Window/Split helpers
keymap('n', '<leader>-', '<C-W>s', { desc = 'Split Window Below', remap = true })
keymap('n', '<leader>|', '<C-W>v', { desc = 'Split Window Right', remap = true })
keymap('n', '<leader>wd', '<C-W>c', { desc = 'Delete Window', remap = true })

-- Buffers
keymap('n', '<S-h>', '<cmd>bprevious<cr>', { desc = 'Prev Buffer' })
keymap('n', '<S-l>', '<cmd>bnext<cr>', { desc = 'Next Buffer' })
keymap('n', '[b', '<cmd>bprevious<cr>', { desc = 'Prev Buffer' })
keymap('n', ']b', '<cmd>bnext<cr>', { desc = 'Next Buffer' })
keymap('n', '<leader>bb', '<cmd>e #<cr>', { desc = 'Switch to Other Buffer' })
keymap('n', '<leader>`', '<cmd>e #<cr>', { desc = 'Switch to Other Buffer' })
keymap('n', '<leader>bo', function()
	local ok, snacks = pcall(require, 'snacks')
	if ok and snacks.bufdelete and snacks.bufdelete.other then
		snacks.bufdelete.other()
	else
		vim.cmd [[silent! %bd|e#|bd#]]
	end
end, { desc = 'Delete Other Buffers' })
keymap('n', '<leader>bD', '<cmd>:bd<cr>', { desc = 'Delete Buffer and Window' })

-- Better visual indent
keymap('v', '<', '<gv')
keymap('v', '>', '>gv')

-- Insert-mode undo break-points
keymap('i', ',', ',<c-g>u')
keymap('i', '.', '.<c-g>u')
keymap('i', ';', ';<c-g>u')


-- Diagnostics navigation
local function diagnostic_goto(next, severity)
	local go = next and vim.diagnostic.goto_next or vim.diagnostic.goto_prev
	severity = severity and vim.diagnostic.severity[severity] or nil
	return function()
		go { severity = severity }
	end
end
keymap('n', ']d', diagnostic_goto(true), { desc = 'Next Diagnostic' })
keymap('n', '[d', diagnostic_goto(false), { desc = 'Prev Diagnostic' })
keymap('n', ']e', diagnostic_goto(true, 'ERROR'), { desc = 'Next Error' })
keymap('n', '[e', diagnostic_goto(false, 'ERROR'), { desc = 'Prev Error' })
keymap('n', ']w', diagnostic_goto(true, 'WARN'), { desc = 'Next Warning' })
keymap('n', '[w', diagnostic_goto(false, 'WARN'), { desc = 'Prev Warning' })

-- Quickfix / Location list toggles
keymap('n', '<leader>xl', function()
	local ok, err = pcall(vim.fn.getloclist(0, { winid = 0 }).winid ~= 0 and vim.cmd.lclose or vim.cmd.lopen)
	if not ok and err then
		vim.notify(err, vim.log.levels.ERROR)
	end
end, { desc = 'Location List' })
keymap('n', '<leader>xq', function()
	local ok, err = pcall(vim.fn.getqflist({ winid = 0 }).winid ~= 0 and vim.cmd.cclose or vim.cmd.copen)
	if not ok and err then
		vim.notify(err, vim.log.levels.ERROR)
	end
end, { desc = 'Quickfix List' })

-- Lazy, New File, Keywordprg, Redraw
keymap('n', '<leader>l', '<cmd>Lazy<cr>', { desc = 'Lazy' })
keymap('n', '<leader>fn', '<cmd>enew<cr>', { desc = 'New File' })
keymap('n', '<leader>K', '<cmd>norm! K<cr>', { desc = 'Keywordprg' })
keymap('n', '<leader>ur', '<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>',
	{ desc = 'Redraw / Clear hlsearch / Diff Update' })
keymap('n', '<leader>ui', vim.show_pos, { desc = 'Inspect Pos' })
keymap('n', '<leader>uI', function()
	vim.treesitter.inspect_tree()
	vim.api.nvim_input 'I'
end, { desc = 'Inspect Tree' })

-- Code (LSP) helpers
keymap('n', '<leader>cli', '<cmd>LspInfo<cr>', { desc = 'LSP Info' })
keymap('n', '<leader>clr', '<cmd>LspRestart<cr>', { desc = 'LSP Restart' })
keymap({ 'n', 'x' }, '<leader>ca', function()
	if vim.lsp.buf.code_action then
		vim.lsp.buf.code_action()
	end
end, { desc = 'Code Action' })
keymap('n', 'gd', function()
	vim.lsp.buf.definition()
end, { desc = 'Go to Definition', remap = true })

-- LSP references/impl/type-def/code-actions via mini.pick
keymap('n', 'grr', function()
	local ok, pick = pcall(require, 'mini.pick')
	if ok and pick.builtin and pick.builtin.lsp_references then
		pick.builtin.lsp_references()
		return
	end
	vim.lsp.buf.references()
end, { desc = 'LSP References' })

keymap('n', 'gri', function()
	local ok, pick = pcall(require, 'mini.pick')
	if ok and pick.builtin and pick.builtin.lsp_implementations then
		pick.builtin.lsp_implementations()
		return
	end
	vim.lsp.buf.implementation()
end, { desc = 'LSP Implementations' })

keymap('n', 'grt', function()
	vim.lsp.buf.type_definition()
end, { desc = 'Go to Type Definition' })

keymap('n', 'gra', function()
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
	keymap('i', '<Tab>', function()
		if try_snippet_jump_forward() then
			return ''
		end
		if pumvisible() then
			return '<C-y>'
		end
		return '\t'
	end, { expr = true, desc = 'Jump snippet / confirm completion / Tab' })

	-- Shift-Tab: jump to previous snippet field; else navigate previous completion; else insert Tab
	keymap('i', '<S-Tab>', function()
		if try_snippet_jump_backward() then
			return ''
		end
		if pumvisible() then
			return '<C-p>'
		end
		return '\t'
	end, { expr = true, desc = 'Jump snippet back / previous completion / Tab' })

	-- Enter: do NOT accept completion; just newline (cancel popup if visible)
	keymap('i', '<CR>', function()
		if pumvisible() then
			return '<C-e><CR>'
		end
		return '\n'
	end, { expr = true, desc = 'Newline (no completion confirm)' })

	-- Navigate with arrows when popup is visible
	keymap('i', '<Down>', function()
		if pumvisible() then
			return '<C-n>'
		end
		return '<Down>'
	end, { expr = true, desc = 'Next completion item' })

	keymap('i', '<Up>', function()
		if pumvisible() then
			return '<C-p>'
		end
		return '<Up>'
	end, { expr = true, desc = 'Prev completion item' })

	-- Ensure Ctrl-n / Ctrl-p navigate items (even if some plugin remaps them)
	keymap('i', '<C-n>', function()
		if pumvisible() then
			return '<C-n>'
		end
		return '<C-n>'
	end, { expr = true, desc = 'Next completion item' })

	keymap('i', '<C-p>', function()
		if pumvisible() then
			return '<C-p>'
		end
		return '<C-p>'
	end, { expr = true, desc = 'Prev completion item' })

	-- Keep arrows for cmdline history; use <C-n>/<C-p> for completion
end

-- Flash (jump/search)
keymap({ 'n', 'x', 'o' }, 's', function()
	local ok, f = pcall(require, 'flash')
	if ok then
		f.jump()
	end
end, { desc = 'Flash' })
keymap({ 'n', 'x', 'o' }, 'S', function()
	local ok, f = pcall(require, 'flash')
	if ok then
		f.treesitter()
	end
end, { desc = 'Flash Treesitter' })
keymap('o', 'r', function()
	local ok, f = pcall(require, 'flash')
	if ok then
		f.remote()
	end
end, { desc = 'Remote Flash' })
keymap({ 'o', 'x' }, 'R', function()
	local ok, f = pcall(require, 'flash')
	if ok then
		f.treesitter_search()
	end
end, { desc = 'Treesitter Search' })
keymap('c', '<c-s>', function()
	local ok, f = pcall(require, 'flash')
	if ok then
		f.toggle()
	end
end, { desc = 'Toggle Flash Search' })

-- Tmux Navigator
keymap('n', '<c-Left>', '<cmd>TmuxNavigateLeft<cr>', { desc = 'Tmux Left' })
keymap('n', '<c-h>', '<cmd>TmuxNavigateLeft<cr>', { desc = 'Tmux Left' })
keymap('n', '<c-Down>', '<cmd>TmuxNavigateDown<cr>', { desc = 'Tmux Down' })
keymap('n', '<c-j>', '<cmd>TmuxNavigateDown<cr>', { desc = 'Tmux Down' })
keymap('n', '<c-Up>', '<cmd>TmuxNavigateUp<cr>', { desc = 'Tmux Up' })
keymap('n', '<c-k>', '<cmd>TmuxNavigateUp<cr>', { desc = 'Tmux Up' })
keymap('n', '<c-Right>', '<cmd>TmuxNavigateRight<cr>', { desc = 'Tmux Right' })
keymap('n', '<c-l>', '<cmd>TmuxNavigateRight<cr>', { desc = 'Tmux Right' })
keymap('n', '<c-\\>', '<cmd>TmuxNavigatePrevious<cr>', { desc = 'Tmux Previous' })

-- Yanky
keymap({ 'n', 'x' }, 'y', '<Plug>(YankyYank)', { desc = 'Yank Text' })
keymap({ 'n', 'x' }, 'p', '<Plug>(YankyPutAfter)', { desc = 'Put After' })
keymap({ 'n', 'x' }, 'P', '<Plug>(YankyPutBefore)', { desc = 'Put Before' })
keymap({ 'n', 'x' }, 'gp', '<Plug>(YankyGPutAfter)', { desc = 'GPut After' })
keymap({ 'n', 'x' }, 'gP', '<Plug>(YankyGPutBefore)', { desc = 'GPut Before' })
keymap('n', '[y', '<Plug>(YankyCycleForward)', { desc = 'Yank Cycle Fwd' })
keymap('n', ']y', '<Plug>(YankyCycleBackward)', { desc = 'Yank Cycle Back' })
keymap('n', ']p', '<Plug>(YankyPutIndentAfterLinewise)', { desc = 'Put Indented After (Linewise)' })
keymap('n', '[p', '<Plug>(YankyPutIndentBeforeLinewise)', { desc = 'Put Indented Before (Linewise)' })
keymap('n', ']P', '<Plug>(YankyPutIndentAfterLinewise)', { desc = 'Put Indented After (Linewise)' })
keymap('n', '[P', '<Plug>(YankyPutIndentBeforeLinewise)', { desc = 'Put Indented Before (Linewise)' })
keymap('n', '>p', '<Plug>(YankyPutIndentAfterShiftRight)', { desc = 'Put and Indent Right' })
keymap('n', '<p', '<Plug>(YankyPutIndentAfterShiftLeft)', { desc = 'Put and Indent Left' })
keymap('n', '>P', '<Plug>(YankyPutIndentBeforeShiftRight)', { desc = 'Put Before and Indent Right' })
keymap('n', '<P', '<Plug>(YankyPutIndentBeforeShiftLeft)', { desc = 'Put Before and Indent Left' })
keymap('n', '=p', '<Plug>(YankyPutAfterFilter)', { desc = 'Put After Filter' })
keymap('n', '=P', '<Plug>(YankyPutBeforeFilter)', { desc = 'Put Before Filter' })
keymap({ 'n', 'x' }, '<leader>p', function()
	local ok, pick = pcall(require, 'mini.pick')
	if ok and pick.builtin and pick.builtin.yanky then
		pick.builtin.yanky()
		return
	end
	vim.cmd [[YankyRingHistory]]
end, { desc = 'Open Yank History' })

-- Overseer
keymap('n', '<leader>o', '<nop>', { desc = 'Overseer' })
keymap('n', '<leader>ot', '<cmd>OverseerToggle<cr>', { desc = 'Overseer Toggle' })
keymap('n', '<leader>oa', '<cmd>OverseerTaskAction<cr>', { desc = 'Overseer Task Action' })
keymap('n', '<leader>or', '<cmd>OverseerRun<cr>', { desc = 'Overseer Run' })

-- Grug-Far
keymap('n', '<leader>sg', function()
	local ok, g = pcall(require, 'grug-far')
	if ok then
		g.open()
	end
end, { desc = 'Search (grug-far)' })

-- SQL: Dadbod UI
keymap('n', '<leader>D', '<cmd>DBUIToggle<CR>', { desc = 'Toggle DBUI' })

-- DAP core
keymap('n', '<leader>dB', function()
	require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
end, { desc = 'Breakpoint Condition' })
keymap('n', '<leader>db', function()
	require('dap').toggle_breakpoint()
end, { desc = 'Toggle Breakpoint' })
keymap('n', '<leader>dl', function()
	require('dap').run_last()
end, { desc = 'Run Last' })
keymap('n', '<leader>ds', function()
	require('dap').session()
end, { desc = 'Session' })
keymap('n', '<leader>dt', function()
	require('dap').terminate()
end, { desc = 'Terminate' })

-- Debugmaster toggle
keymap('n', '<leader>dd', function()
	local ok, dm = pcall(require, 'debugmaster')
	if ok then
		dm.mode.toggle()
	end
end, { desc = 'Toggle Debug Mode' })

-- Neotest
keymap('n', '<leader>t', '<nop>', { desc = '+test' })
keymap('n', '<leader>tt', function()
	require('neotest').run.run(vim.fn.expand '%')
end, { desc = 'Run File' })
keymap('n', '<leader>tT', function()
	require('neotest').run.run(vim.uv.cwd())
end, { desc = 'Run All Files' })
keymap('n', '<leader>tr', function()
	require('neotest').run.run()
end, { desc = 'Run Nearest' })
keymap('n', '<leader>tl', function()
	require('neotest').run.run_last()
end, { desc = 'Run Last' })
keymap('n', '<leader>ts', function()
	require('neotest').summary.toggle()
end, { desc = 'Toggle Summary' })
keymap('n', '<leader>to', function()
	require('neotest').output.open { enter = true, auto_close = true }
end, { desc = 'Show Output' })
keymap('n', '<leader>tO', function()
	require('neotest').output_panel.toggle()
end, { desc = 'Toggle Output Panel' })
keymap('n', '<leader>tS', function()
	require('neotest').run.stop()
end, { desc = 'Stop Tests' })
keymap('n', '<leader>tw', function()
	require('neotest').watch.toggle(vim.fn.expand '%')
end, { desc = 'Toggle Watch' })
keymap('n', '<leader>td', function()
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
				return vim.g.disable_autoformat
			end,
			set = function(state)
				vim.g.disable_autoformat = not state
			end
		})
	end,
})

-- Tabs suite
keymap('n', '<leader><tab>l', '<cmd>tablast<cr>', { desc = 'Last Tab' })
keymap('n', '<leader><tab>o', '<cmd>tabonly<cr>', { desc = 'Close Other Tabs' })
keymap('n', '<leader><tab>f', '<cmd>tabfirst<cr>', { desc = 'First Tab' })
keymap('n', '<leader><tab><tab>', '<cmd>tabnew<cr>', { desc = 'New Tab' })
keymap('n', '<leader><tab>]', '<cmd>tabnext<cr>', { desc = 'Next Tab' })
keymap('n', '<leader><tab>d', '<cmd>tabclose<cr>', { desc = 'Close Tab' })
keymap('n', '<leader><tab>[', '<cmd>tabprevious<cr>', { desc = 'Previous Tab' })

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
	keymap('n', '<leader>g', '<nop>', { desc = '+git' })

	-- hunk actions
	keymap('n', '<leader>gs', with_gitsigns 'stage_hunk', { desc = 'Stage Hunk' })
	keymap('n', '<leader>gr', with_gitsigns 'reset_hunk', { desc = 'Reset Hunk' })
	keymap('v', '<leader>gs', with_gitsigns 'stage_hunk', { desc = 'Stage Hunk' })
	keymap('v', '<leader>gr', with_gitsigns 'reset_hunk', { desc = 'Reset Hunk' })
	keymap('n', '<leader>gu', with_gitsigns 'undo_stage_hunk', { desc = 'Undo Stage Hunk' })
	keymap('n', '<leader>gS', with_gitsigns 'stage_buffer', { desc = 'Stage Buffer' })
	keymap('n', '<leader>gR', with_gitsigns 'reset_buffer', { desc = 'Reset Buffer' })
	keymap('n', '<leader>gp', with_gitsigns 'preview_hunk', { desc = 'Preview Hunk' })

	-- navigation
	keymap('n', '<leader>gj', with_gitsigns 'next_hunk', { desc = 'Next Hunk' })
	keymap('n', '<leader>gk', with_gitsigns 'prev_hunk', { desc = 'Prev Hunk' })

	-- toggles and info
	keymap('n', '<leader>gb', with_gitsigns 'blame_line', { desc = 'Blame Line' })
	keymap('n', '<leader>gB', with_gitsigns 'toggle_current_line_blame', { desc = 'Toggle Blame' })
	keymap('n', '<leader>gt', with_gitsigns 'toggle_deleted', { desc = 'Toggle Deleted' })

	-- diff
	keymap('n', '<leader>gd', with_gitsigns 'diffthis', { desc = 'Diff This' })
	keymap('n', '<leader>gD', function()
		with_gitsigns 'diffthis' '~'
	end, { desc = 'Diff This (~)' })

	-- select hunk
	keymap({ 'n', 'v' }, '<leader>gh', with_gitsigns 'select_hunk', { desc = 'Select Hunk' })
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
	keymap('n', '<leader>ff', with_pick('files', { cwd = root() }), { desc = 'Find Files (Root Dir)' })
	keymap('n', '<leader><leader>', '<leader>ff', { desc = 'Find Files (Root Dir)', remap = true })
	keymap('n', '<leader>fF', with_pick('files', { cwd = vim.uv.cwd() }), { desc = 'Find Files (cwd)' })
	keymap('n', '<leader>fb', with_pick 'buffers', { desc = 'Buffers' })
	keymap('n', '<leader>fo', with_pick 'oldfiles', { desc = 'Recent Files' })
	keymap('n', '<leader>fr', with_pick('oldfiles', { cwd = root() }), { desc = 'Recent Files (Root Dir)' })
	keymap('n', '<leader>fR', with_pick 'oldfiles', { desc = 'Recent Files (global)' })
	keymap('n', '<leader>fg', with_pick('files', { cwd = root() }), { desc = 'Find Files (Root Dir)' })

	-- Search
	keymap({ 'n', 'x' }, '<leader>sw', function()
		local word
		if vim.fn.mode():find '[vV\22]' then
			word = vim.fn.getreg '*'
		else
			word = vim.fn.expand '<cword>'
		end
		require('mini.pick').builtin.grep { pattern = word, cwd = root() }
	end, { desc = 'Search Word (Root Dir)' })
	keymap('n', '<leader>/', with_pick('grep_live', { cwd = root() }), { desc = 'Search (Live Grep, Root)' })
	keymap('n', '<leader>?', with_pick('grep_live', { cwd = vim.uv.cwd() }), { desc = 'Search (Live Grep, cwd)' })
	keymap('n', '<leader>sl', with_pick 'lines', { desc = 'Search Lines (buffer)' })
	keymap('n', '<leader>sm', with_pick 'marks', { desc = 'Search Marks' })
	keymap('n', '<leader>sh', with_pick 'help', { desc = 'Help Tags' })

	-- Commands and keymaps pickers (mini.pick)
	keymap('n', '<leader>sC', with_pick 'commands', { desc = 'Search Commands' })
	keymap('n', '<leader>sk', with_pick 'keymaps', { desc = 'Search Keymaps' })
	keymap('n', '<leader>sd', with_pick 'diagnostics', { desc = 'Search Diagnostics' })

	-- LSP pickers (mini.pick custom)
	keymap('n', '<leader>sr', with_pick 'lsp_references', { desc = 'LSP References' })
	keymap('n', '<leader>si', with_pick 'lsp_implementations', { desc = 'LSP Implementations' })
	keymap('n', '<leader>st', with_pick 'lsp_type_definitions', { desc = 'LSP Type Definitions' })
	keymap('n', '<leader>sA', with_pick 'lsp_code_actions', { desc = 'LSP Code Actions' })
	keymap('n', '<leader>ss', with_pick 'lsp_symbols', { desc = 'LSP Symbols' })

	-- Git pickers (mini.pick custom)
	keymap('n', '<leader>sS', with_pick 'git_status', { desc = 'Git Status' })
	keymap('n', '<leader>sB', with_pick 'git_branches', { desc = 'Git Branches' })
	keymap('n', '<leader>sT', with_pick 'git_stash', { desc = 'Git Stash' })
	keymap('n', '<leader>sF', with_pick 'git_log_file', { desc = 'Git File Commits' })
	keymap('n', '<leader>sG', with_pick 'git_log', { desc = 'Git Log' })

	-- (LSP quickfix fallbacks no longer needed; custom mini.pick LSP pickers are mapped above)
end

-- Git Browse (remote URL) via gitlinker
do
	local function gl_action(mode, action)
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
			gitlinker.get_buf_range_url(mode, { action_callback = cb })
		end
	end

	-- open remote in browser
	keymap({ 'n', 'x' }, '<leader>go', gl_action('n', 'open'), { desc = 'Git Browse (open)' })

	-- copy remote URL to clipboard
	keymap({ 'n', 'x' }, '<leader>gy', gl_action('n', 'copy'), { desc = 'Git Browse (copy)' })
end
