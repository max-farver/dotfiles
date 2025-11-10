local helpers = _G.Config.ftplugin_helpers
local project = _G.Config.project

helpers.setup_lsp("terraformls")

vim.b.formatters = project.get_formatters("terraform") or { "terraform_fmt" }
vim.b.linters = project.get_linters("terraform") or { "terraform_validate" }
