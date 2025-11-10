local M = {}

local function cwd_name()
	local cwd = vim.loop.cwd() or vim.fn.getcwd()
	return vim.fs.basename(cwd)
end

local function format_path()
	local bufname = vim.api.nvim_buf_get_name(0)
	if bufname == "" then
		return "[No Name]"
	end
	local cwd = (vim.loop.cwd() or vim.fn.getcwd()) .. "/"
	if bufname:find(cwd, 1, true) == 1 then
		bufname = bufname:sub(#cwd + 1)
	end
	return bufname
end

function M.root_dir_component()
	return {
		cwd_name,
		icon = "󱂬",
		separator = " ",
	}
end

function M.pretty_path_component()
	return {
		format_path,
		separator = " ",
	}
end

return M
