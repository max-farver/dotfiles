local project = _G.Config.project

local formatters = project.get_formatters("zshrc")
if formatters then
	vim.b.formatters = formatters
end

local linters = project.get_linters("zshrc")
if linters then
	vim.b.linters = linters
end
