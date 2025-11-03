local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local reload_group = augroup('user_auto_reload', { clear = true })
autocmd('FocusGained', {
	group = reload_group,
	desc = 'Reload files from disk when the editor regains focus',
	pattern = '*',
	command = "if getcmdwintype() == '' | checktime | endif",
})
autocmd({ 'TermClose', 'TermLeave' }, {
	group = reload_group,
	desc = 'Reload files when terminal closes/leaves',
	pattern = '*',
	command = "if getcmdwintype() == '' | checktime | endif",
})
autocmd('BufEnter', {
	group = reload_group,
	desc = 'Check for external file changes on buffer enter',
	pattern = '*',
	command =
	"if &buftype == '' && !&modified && expand('%') != '' | execute 'checktime ' .. expand('<abuf>') | endif",
})

-- Close certain filetypes quickly with q
autocmd('FileType', {
	group = augroup('user_close_with_q', { clear = true }),
	pattern = {
		'PlenaryTestPopup',
		'checkhealth',
		'dbout',
		'gitsigns-blame',
		'grug-far',
		'help',
		'lspinfo',
		'neotest-output',
		'neotest-output-panel',
		'neotest-summary',
		'notify',
		'qf',
		'spectre_panel',
		'startuptime',
		'tsplayground',
	},
	callback = function(event)
		vim.bo[event.buf].buflisted = false
		vim.schedule(function()
			vim.keymap.set('n', 'q', function()
				vim.cmd 'close'
				pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
			end, { buffer = event.buf, silent = true, desc = 'Quit buffer' })
		end)
	end,
})

-- Make inline man pages unlisted
autocmd('FileType', {
	group = augroup('user_man_unlisted', { clear = true }),
	pattern = { 'man' },
	callback = function(event)
		vim.bo[event.buf].buflisted = false
	end,
})

-- Auto create directories on save if missing
autocmd('BufWritePre', {
	group = augroup('user_auto_create_dir', { clear = true }),
	callback = function(event)
		if event.match:match '^%w%w+:[\\/][\\/]' then
			return
		end
		local file = vim.uv.fs_realpath(event.match) or event.match
		vim.fn.mkdir(vim.fn.fnamemodify(file, ':p:h'), 'p')
	end,
})

-- Auto enable treesitter for any real buffer
autocmd('FileType', {
	group = augroup('user_auto_treesitter', { clear = true }),
	pattern = '*',
	callback = function(event)
		if vim.bo[event.buf].buftype ~= '' or vim.bo[event.buf].filetype == '' then
			return
		end
		pcall(vim.treesitter.start, event.buf)
	end,
})

-- Autoformat
vim.api.nvim_create_user_command("FormatDisable", function(args)
	if args.bang then
		-- FormatDisable! will disable formatting just for this buffer
		vim.b.disable_autoformat = true
	else
		vim.g.disable_autoformat = true
	end
end, {
	desc = "Disable autoformat-on-save",
	bang = true,
})

vim.api.nvim_create_user_command("FormatEnable", function()
	vim.b.disable_autoformat = false
	vim.g.disable_autoformat = false
end, {
	desc = "Re-enable autoformat-on-save",
})

vim.api.nvim_create_user_command("Format", function(args)
	local range = nil
	if args.count ~= -1 then
		local end_line = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
		range = {
			start = { args.line1, 0 },
			["end"] = { args.line2, end_line:len() },
		}
	end
	require("conform").format({ async = true, lsp_format = "fallback", range = range })
end, { range = true })
