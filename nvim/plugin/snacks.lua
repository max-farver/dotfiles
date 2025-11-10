if vim.g.vscode then
	return
end

local add = MiniDeps.add
local now = MiniDeps.now

now(function()
	add("folke/snacks.nvim")
	local snacks = require('snacks')
	snacks.setup({
		statuscolumn = {},
		toggle = {},
	})


	local map = function(mode, lhs, rhs, opts)
		opts = opts or {}
		opts.silent = opts.silent ~= false
		vim.keymap.set(mode, lhs, rhs, opts)
	end

	local function nmap(lhs, rhs, opts)
		map('n', lhs, rhs, opts)
	end
	local function nmap_leader(keys, rhs, desc, opts)
		opts = opts or {}
		opts.desc = desc or opts.desc
		nmap('<leader>' .. keys, rhs, opts)
	end

	local toggle = snacks.toggle

	local spell = toggle.option('spell', { name = 'Spelling' })
	nmap_leader('us', function()
		spell:toggle()
	end, 'Toggle Spelling')

	local wrap = toggle.option('wrap', { name = 'Wrap' })
	nmap_leader('uw', function()
		wrap:toggle()
	end, 'Toggle Wrap')

	local line_numbers = toggle.line_number()
	nmap_leader('ul', function()
		line_numbers:toggle()
	end, 'Toggle Line Numbers')

	local relnum = toggle.option('relativenumber', { name = 'Relative Number' })
	nmap_leader('uL', function()
		relnum:toggle()
	end, 'Toggle Relative Number')

	local diagnostics = toggle.diagnostics()
	nmap_leader('ud', function()
		diagnostics:toggle()
	end, 'Toggle Diagnostics')

	local treesitter = toggle.treesitter()
	nmap_leader('uT', function()
		treesitter:toggle()
	end, 'Toggle Treesitter Highlight')

	local conceal = toggle.option('conceallevel', {
		off = 0,
		on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2,
		name = 'Conceal Level',
	})
	nmap_leader('uc', function()
		conceal:toggle()
	end, 'Toggle Conceal Level')

	local tabline = toggle.option('showtabline', {
		off = 0,
		on = vim.o.showtabline > 0 and vim.o.showtabline or 2,
		name = 'Tabline',
	})
	nmap_leader('uA', function()
		tabline:toggle()
	end, 'Toggle Tabline')

	local background = toggle.option('background', { off = 'light', on = 'dark', name = 'Dark Background' })
	nmap_leader('ub', function()
		background:toggle()
	end, 'Toggle Dark Background')

	local dim = toggle.dim()
	nmap_leader('uD', function()
		dim:toggle()
	end, 'Toggle Dim')

	local animate = toggle.animate()
	nmap_leader('ua', function()
		animate:toggle()
	end, 'Toggle Animate')

	local indent = toggle.indent()
	nmap_leader('ug', function()
		indent:toggle()
	end, 'Toggle Indent Guides')

	local scroll = toggle.scroll()
	nmap_leader('uS', function()
		scroll:toggle()
	end, 'Toggle Scroll')

	local profiler = toggle.profiler()
	nmap_leader('dpp', function()
		profiler:toggle()
	end, 'Toggle Snacks Profiler')

	local profiler_highlights = toggle.profiler_highlights()
	nmap_leader('dph', function()
		profiler_highlights:toggle()
	end, 'Toggle Profiler Highlights')

	if vim.lsp.inlay_hint then
		local inlay = toggle.inlay_hints()
		nmap_leader('uh', function()
			inlay:toggle()
		end, 'Toggle Inlay Hints')
	end

	local autoformat = toggle.new({
		id = 'autoformat',
		name = 'Autoformat',
		get = function()
			return not vim.g.disable_autoformat
		end,
		set = function(state)
			vim.g.disable_autoformat = not state
		end,
	})
	nmap_leader('uf', function()
		autoformat:toggle()
	end, 'Toggle Autoformat')
end)
