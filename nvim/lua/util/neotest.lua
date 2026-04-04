local M = {}

local state = {
	base_opts = nil,
	extra_adapters = {},
	adapters = {},
}

local function notify(msg, level)
	vim.schedule(function()
		vim.notify(msg, level or vim.log.levels.WARN)
	end)
end

local function build_adapters()
	local adapters = {}
	local names = {}
	for name in pairs(state.adapters) do
		table.insert(names, name)
	end
	table.sort(names)

	for _, name in ipairs(names) do
		local entry = state.adapters[name]
		local ok, adapter = pcall(entry.factory)
		if ok and adapter then
			table.insert(adapters, adapter)
		else
			notify(string.format("Failed to load neotest adapter '%s': %s", name, adapter), vim.log.levels.ERROR)
		end
	end

	for _, adapter in ipairs(state.extra_adapters) do
		table.insert(adapters, adapter)
	end

	return adapters
end

function M.setup(base_opts)
	state.base_opts = vim.deepcopy(base_opts or {})
	state.extra_adapters = {}

	if type(state.base_opts.adapters) == "table" then
		for _, adapter in ipairs(state.base_opts.adapters) do
			table.insert(state.extra_adapters, adapter)
		end
	end

	state.base_opts.adapters = {}
	return M.refresh()
end

function M.register_adapter(name, factory)
	if type(name) ~= "string" or name == "" then
		return false, "adapter name must be a non-empty string"
	end
	if type(factory) ~= "function" then
		return false, "adapter factory must be a function"
	end
	if state.adapters[name] then
		return true
	end

	state.adapters[name] = { factory = factory }
	if state.base_opts then
		M.refresh()
	end
	return true
end

function M.has_adapter(name)
	return state.adapters[name] ~= nil
end

function M.refresh()
	if not state.base_opts then
		return false, "neotest base options not initialized"
	end

	local ok_neotest, neotest = pcall(require, "neotest")
	if not ok_neotest then
		return false, "neotest is not available"
	end

	local opts = vim.deepcopy(state.base_opts)
	opts.adapters = build_adapters()

	local ok_setup, err = pcall(neotest.setup, opts)
	if not ok_setup then
		notify(string.format("Failed to configure neotest: %s", err), vim.log.levels.ERROR)
		return false, err
	end

	return true
end

return M
