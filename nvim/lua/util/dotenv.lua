local M = {}

--- Load environment variables from a .env file into vim.env
--- @param path? string Path to the .env file (default: ".env")
function M.load(path)
	path = path or ".env"
	local file = io.open(path, "r")
	if not file then
		return
	end
	for line in file:lines() do
		local key, val = line:match("^([%w_]+)%s*=%s*(.+)$")
		if key and not line:match("^#") then
			val = val:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
			vim.env[key] = val
		end
	end
	file:close()
end

return M
