local helpers = _G.Config.ftplugin_helpers
local filetype = vim.bo.filetype

vim.opt_local.conceallevel = 0

if filetype == "json" or filetype == "jsonc" then
	helpers.setup_schemastore_lsp("jsonls")
end
