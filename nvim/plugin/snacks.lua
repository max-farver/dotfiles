if vim.g.vscode then
	return
end

local add_once = _G.Config.pack_add_once or _G.Config.pack_add
local now = _G.Config.now
local nmap_leader = _G.Config.nmap_leader

now(function()
	add_once({ { src = "https://github.com/folke/snacks.nvim" } })
	local snacks = require('snacks')
	snacks.setup({
		statuscolumn = {},
		toggle = {},
	})

	local toggle = snacks.toggle

	local spell = toggle.option('spell', { name = 'Spelling' })
	nmap_leader('us', function()
		spell:toggle()
	end, 'Toggle Spelling')

	local wrap = toggle.option('wrap', { name = 'Wrap' })
	nmap_leader('uw', function()
		wrap:toggle()
	end, 'Toggle Wrap')

	local diagnostics = toggle.diagnostics()
	nmap_leader('ud', function()
		diagnostics:toggle()
	end, 'Toggle Diagnostics')

	local treesitter = toggle.treesitter()
	nmap_leader('uT', function()
		treesitter:toggle()
	end, 'Toggle Treesitter Highlight')

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
