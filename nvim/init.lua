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

-- Bootstrap 'mini.nvim' manually in a way that it gets managed by 'mini.deps'
local mini_path = vim.fn.stdpath('data') .. '/site/pack/deps/start/mini.nvim'
if not vim.uv.fs_stat(mini_path) then
	vim.cmd('echo "Installing `mini.nvim`" | redraw')
	local origin = 'https://github.com/max-farver/mini.nvim'
	local clone_cmd = { 'git', 'clone', '--filter=blob:none', origin, mini_path }
	vim.fn.system(clone_cmd)
	vim.cmd('packadd mini.nvim | helptags ALL')
	vim.cmd('echo "Installed `mini.nvim`" | redraw')
end

-- Set this immediately so that project level options are loaded correctly
vim.opt.exrc = true


-- Plugin manager. Set up immediately for `now()`/`later()` helpers.
-- Example usage:
-- - `MiniDeps.add('...')` - use inside config to add a plugin
-- - `:DepsUpdate` - update all plugins
-- - `:DepsSnapSave` - save a snapshot of currently active plugins
--
-- See also:
-- - `:h MiniDeps-overview` - how to use it
-- - `:h MiniDeps-commands` - all available commands
-- - 'plugin/30_mini.lua' - more details about 'mini.nvim' in general
require('mini.deps').setup()

-- Define config table to be able to pass data between scripts
_G.Config = {}

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
_G.Config.now_if_args = vim.fn.argc(-1) > 0 and MiniDeps.now or MiniDeps.later


_G.Config.ftplugin_helpers = require('util.ftplugin_helpers')
_G.Config.os = require('util.os')
_G.Config.icons = require('util.icons')
_G.Config.project = require('util.project')
_G.Config.root = require('util.root')
_G.Config.statusline = require('util.statusline')
