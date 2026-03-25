local map = _G.Config.map
local nmap = _G.Config.nmap
local nmap_leader = _G.Config.nmap_leader

map({ 'n', 'x' }, '<C-d>', '<C-d>zz', { desc = 'Half page down centered' })
map({ 'n', 'x' }, '<C-u>', '<C-u>zz', { desc = 'Half page up centered' })
map('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear highlight' })
nmap_leader('qq', '<cmd>confirm qa<CR>', 'Quit all')
nmap_leader('ww', '<cmd>w<CR>', 'Save')
nmap_leader('bd', '<cmd>bd<CR>', 'Delete buffer')
nmap_leader('bn', '<cmd>bnext<CR>', 'Next buffer')
nmap_leader('bp', '<cmd>bprevious<CR>', 'Previous buffer')

-- Save file
map({ 'i', 'x', 'n', 's' }, '<C-s>', '<cmd>w<cr><esc>', { desc = 'Save File' })

-- Window/Split helpers
nmap_leader('-', '<C-W>s', 'Split Window Below', { remap = true })
nmap_leader('|', '<C-W>v', 'Split Window Right', { remap = true })
nmap_leader('wd', '<C-W>c', 'Delete Window', { remap = true })

-- Buffers
map('n', '<S-h>', '<cmd>bprevious<cr>', { desc = 'Prev Buffer' })
map('n', '<S-l>', '<cmd>bnext<cr>', { desc = 'Next Buffer' })
map('n', '[b', '<cmd>bprevious<cr>', { desc = 'Prev Buffer' })
map('n', ']b', '<cmd>bnext<cr>', { desc = 'Next Buffer' })
nmap_leader('bb', '<cmd>e #<cr>', 'Switch to Other Buffer')
nmap_leader('`', '<cmd>e #<cr>', 'Switch to Other Buffer')
map('n', '<leader>bo', function()
	local ok, snacks = pcall(require, 'snacks')
	if ok and snacks.bufdelete and snacks.bufdelete.other then
		snacks.bufdelete.other()
	else
		vim.cmd [[silent! %bd|e#|bd#]]
	end
end, { desc = 'Delete Other Buffers' })
nmap_leader('bD', '<cmd>bd<cr>', 'Delete Buffer and Window')

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

-- New File, Keywordprg, Redraw
nmap_leader('fn', '<cmd>enew<cr>', 'New File')
nmap_leader('K', '<cmd>norm! K<cr>', 'Keywordprg')
nmap_leader('ur', '<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>',
	'Redraw / Clear hlsearch / Diff Update')
nmap_leader('ui', '<Cmd>lua vim.show_pos()<CR>', 'Inspect Pos')
map('n', '<leader>uI', function()
	vim.treesitter.inspect_tree()
	vim.api.nvim_input 'I'
end, { desc = 'Inspect Tree' })

-- Tabs suite

nmap_leader('<tab>l', '<cmd>tablast<cr>', 'Last Tab')
nmap_leader('<tab>o', '<cmd>tabonly<cr>', 'Close Other Tabs')
nmap_leader('<tab>f', '<cmd>tabfirst<cr>', 'First Tab')
nmap_leader('<tab><tab>', '<cmd>tabnew<cr>', 'New Tab')
nmap_leader('<tab>]', '<cmd>tabnext<cr>', 'Next Tab')
nmap_leader('<tab>d', '<cmd>tabclose<cr>', 'Close Tab')
nmap_leader('<tab>[', '<cmd>tabprevious<cr>', 'Previous Tab')
