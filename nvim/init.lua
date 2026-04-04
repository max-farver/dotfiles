-- ┌────────────────────┐
-- │ Welcome to MiniMax │
-- └────────────────────┘
--
-- This is a config designed to mostly use MINI. It provides out of the box
-- a stable, polished, and feature rich Neovim experience. Its structure:
--
-- ├ init.lua          Initial (this) file executed during startup
-- ├ plugin/           Files automatically sourced during startup
-- ├── 10_options.lua  Built-in Neovim settings
-- ├── 20_autocmds.lua Autocommands
-- ├── 30_keymaps.lua  Custom key mappings
-- ├── mini.lua        mini.nvim module configurations
-- ├── *.lua           Other plugin configurations
-- ├ after/            Files to override behavior added by plugins
-- ├── ftplugin/       Filetype-specific configurations
--
-- Config files are meant to be read, preferably inside a Neovim instance running
-- this config and opened at its root. This will help you better understand your
-- setup. Start with this file. Any order is possible, prefer the one listed above.
-- Ways of navigating your config:
-- - `<Space>` + `e` + (one of) `iokmp` - edit 'init.lua' or 'plugin/' files.
-- - Inside config directory: `<Space>ff` (picker) or `<Space>ed` (explorer)
-- - Navigate existing buffers with `[b`, `]b`, or `<Space>fb`.
--
-- Config files are also meant to be customized. Initially it is a baseline of
-- a working config based on MINI. Modify it to make it yours. Some approaches:
-- - Modify already existing files in a way that keeps them consistent.
-- - Add new files in a way that keeps config consistent.
--   Usually inside 'plugin/' or 'after/'.
--
-- Documentation comments like this can be found throughout the config.
-- Common conventions:
--
-- - See `:h key-notation` for key notation used.
-- - `:h xxx` means "documentation of helptag xxx". Either type text directly
--   followed by Enter or type `<Space>fh` to open a helptag fuzzy picker.
-- - "Type `<Space>fh`" means "press <Space>, followed by f, followed by h".
--   Unless said otherwise, it assumes that Normal mode is current.
-- - "See 'path/to/file'" means see open file at described path and read it.
-- - `:SomeCommand ...` or `:lua ...` means execute mentioned command.

-- Set this immediately so that project level options are loaded correctly
vim.opt.exrc = true

-- Disable built-in plugins we don't use (startup win)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_matchit = 1

-- Define config table to be able to pass data between scripts
_G.Config = {}

-- `vim.pack` helpers
_G.Config.pack_add = function(specs)
	vim.pack.add(specs, { confirm = false })
end

local pack_seen = {}
_G.Config.pack_add_once = function(specs)
	local filtered = {}
	for _, spec in ipairs(specs or {}) do
		local key = spec.src or spec.name
		if not key then
			table.insert(filtered, spec)
		elseif not pack_seen[key] then
			pack_seen[key] = true
			table.insert(filtered, spec)
		end
	end
	if #filtered > 0 then
		vim.pack.add(filtered, { confirm = false })
	end
end

vim.api.nvim_create_autocmd('PackChanged', {
	group = vim.api.nvim_create_augroup('pack-hooks', { clear = true }),
	callback = function(ev)
		if ev.data.kind ~= 'install' and ev.data.kind ~= 'update' then return end
		local name = ev.data.spec and ev.data.spec.name
		if not name then return end
		if name == 'nvim-treesitter' then
			if not ev.data.active then pcall(vim.cmd.packadd, name) end
			pcall(vim.cmd, 'TSUpdate')
		elseif name == 'mason.nvim' then
			if not ev.data.active then pcall(vim.cmd.packadd, name) end
			vim.schedule(function() pcall(vim.cmd, 'MasonUpdate') end)
		elseif name == 'go.nvim' then
			if not ev.data.active then pcall(vim.cmd.packadd, name) end
			pcall(function() require('go.install').update_all_sync() end)
		elseif name == 'markdown-preview.nvim' then
			if not ev.data.active then pcall(vim.cmd.packadd, name) end
			pcall(vim.cmd, 'silent! call mkdp#util#install()')
		end
	end,
})

local function safely(fn)
	if _G.MiniMisc and type(MiniMisc.safely) == 'function' then
		return MiniMisc.safely('now', fn)
	end
	local ok, err = xpcall(fn, debug.traceback)
	if not ok then
		vim.schedule(function() vim.notify(err, vim.log.levels.ERROR) end)
	end
end

local later_queue, later_scheduled = {}, false
local function later(fn)
	if _G.MiniMisc and type(MiniMisc.safely) == 'function' then
		return MiniMisc.safely('later', fn)
	end
	if vim.v.vim_did_enter == 1 then return safely(fn) end
	table.insert(later_queue, fn)
	if later_scheduled then return end
	later_scheduled = true
	vim.api.nvim_create_autocmd('VimEnter', {
		once = true,
		callback = function()
			for _, f in ipairs(later_queue) do
				safely(f)
			end
			later_queue = {}
		end,
	})
end

_G.Config.now = safely
_G.Config.later = later

-- Ensure `mini.nvim` is managed by `vim.pack` and available during startup.
_G.Config.pack_add({ { src = 'https://github.com/nvim-mini/mini.nvim' } })

-- Use MiniMisc.safely() as a startup-safe execution primitive.
require('mini.misc').setup()
if type(MiniMisc.safely) ~= 'function' then
	MiniMisc.safely = function(when, fn)
		if type(when) == 'function' and fn == nil then
			fn = when
			when = 'now'
		end
		if when == 'later' then
			vim.schedule(function()
				local ok, err = xpcall(fn, debug.traceback)
				if not ok then
					vim.notify(err, vim.log.levels.ERROR)
				end
			end)
			return
		end
		local ok, err = xpcall(fn, debug.traceback)
		if not ok then
			vim.schedule(function() vim.notify(err, vim.log.levels.ERROR) end)
		end
	end
end

vim.api.nvim_create_user_command('PackUpdate', function()
	vim.pack.update()
end, { desc = 'Update plugins via vim.pack' })

local gr = vim.api.nvim_create_augroup('custom-config', {})
_G.Config.new_autocmd = function(event, pattern, callback, desc)
	local opts = { group = gr, pattern = pattern, callback = callback, desc = desc }
	vim.api.nvim_create_autocmd(event, opts)
end

-- Keymap registration helpers
_G.Config.map = function(mode, lhs, rhs, opts)
	opts = opts or {}
	opts.silent = opts.silent ~= false
	vim.keymap.set(mode, lhs, rhs, opts)
end

_G.Config.nmap = function(lhs, rhs, desc, opts)
	opts = opts or {}
	opts.desc = desc or opts.desc
	_G.Config.map('n', lhs, rhs, opts)
end

_G.Config.nmap_leader = function(keys, rhs, desc, opts)
	_G.Config.nmap('<leader>' .. keys, rhs, desc, opts)
end

-- Some plugins and 'mini.nvim' modules only need setup during startup if Neovim
-- is started like `nvim -- path/to/file`, otherwise delaying setup is fine
_G.Config.now_if_args = vim.fn.argc(-1) > 0 and _G.Config.now or _G.Config.later


_G.Config.ftplugin_helpers = require('util.ftplugin_helpers')
_G.Config.os = require('util.os')
_G.Config.icons = require('util.icons')
_G.Config.project = require('util.project')
_G.Config.root = require('util.root')
_G.Config.statusline = require('util.statusline')
