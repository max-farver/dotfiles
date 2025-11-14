local uv = vim.uv or vim.loop

local M = {}

local state_file = vim.fs.normalize(vim.fn.stdpath("state") .. "/theme_pref.json")
local state_dir = vim.fs.dirname(state_file)

M.variants = {
	dark = {
		colorscheme = "dracula",
		aliases = { "dracula" },
	},
	light = {
		colorscheme = "github_light",
		aliases = { "github_light", "github_light_default" },
	},
}

local default_variant = "dark"

local colorscheme_to_variant = {}
for variant, entry in pairs(M.variants) do
	entry.aliases = entry.aliases or { entry.colorscheme }
	entry.colorscheme = entry.colorscheme or entry.aliases[1]
	for _, name in ipairs(entry.aliases) do
		colorscheme_to_variant[name] = variant
	end
end

local function read_file(path)
	local fd = uv.fs_open(path, "r", 0)
	if not fd then
		return nil
	end

	local stat = uv.fs_fstat(fd)
	if not stat then
		uv.fs_close(fd)
		return nil
	end

	local data = uv.fs_read(fd, stat.size, 0)
	uv.fs_close(fd)
	return data
end

local function write_file(path, contents)
	if not state_dir or state_dir == "" then
		return false
	end
	vim.fn.mkdir(state_dir, "p")

	local fd = uv.fs_open(path, "w", 420) -- 0644
	if not fd then
		return false
	end

	uv.fs_write(fd, contents, 0)
	uv.fs_close(fd)
	return true
end

local function read_saved_variant()
	local data = read_file(state_file)
	if not data or data == "" then
		return nil
	end

	local ok, decoded = pcall(vim.json.decode, data)
	if not ok or type(decoded) ~= "table" then
		return nil
	end

	if decoded.variant and M.variants[decoded.variant] then
		return decoded.variant
	end
	return nil
end

local function persist_variant(variant)
	if not variant or not M.variants[variant] then
		return
	end
	write_file(state_file, vim.json.encode({ variant = variant }))
end

function M.apply(variant)
	local entry = M.variants[variant]
	if not entry then
		return false, string.format("Unknown theme variant '%s'", tostring(variant))
	end

	local ok, err = pcall(vim.cmd.colorscheme, entry.colorscheme)
	if not ok then
		return false, err
	end

	persist_variant(variant)
	return true
end

function M.load_last()
	local variant = read_saved_variant() or default_variant
	local ok, err = M.apply(variant)
	if ok then
		return
	end

	if variant ~= default_variant then
		local fallback_ok, fallback_err = M.apply(default_variant)
		if not fallback_ok then
			vim.notify(
				string.format("Failed to load theme. Errors: %s; fallback: %s", err, fallback_err),
				vim.log.levels.ERROR
			)
		end
	else
		vim.notify(string.format("Failed to load theme: %s", err), vim.log.levels.ERROR)
	end
end

function M.on_colorscheme(colorscheme)
	local variant = colorscheme_to_variant[colorscheme]
	if variant then
		persist_variant(variant)
	end
end

function M.toggle()
	local next_variant = "dark"
	if colorscheme_to_variant[vim.g.colors_name or ""] == "dark" then
		next_variant = "light"
	end
	M.apply(next_variant)
end

return M
