-- Core bootstrap
vim.g.mapleader = " "
vim.g.maplocalleader = ","

require("config.options")
require("config.autocmds")
require("config.keymaps")
require("util.ft_registry")

-- Load project-specific config BEFORE lazy.nvim setup
-- This ensures project overrides are available when ftplugin files are collected
local nvim_lua = vim.fn.getcwd() .. "/.nvim.lua"
if vim.fn.filereadable(nvim_lua) == 1 then
	-- Use vim.secure.read for trust checking (requires Neovim 0.9+)
	local content = vim.secure.read(nvim_lua)
	if content then
		local chunk, load_err = load(content, "@.nvim.lua")
		if chunk then
			local success, exec_err = pcall(chunk)
			if not success then
				vim.notify("Error executing .nvim.lua: " .. exec_err, vim.log.levels.ERROR)
			end
		else
			vim.notify("Error loading .nvim.lua: " .. load_err, vim.log.levels.ERROR)
		end
	end
end

require("config.lazy")

pcall(vim.cmd.colorscheme, "dracula")
