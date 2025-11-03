-- ============================================================================
-- PHASE 1: Plugin Declarations (evaluated at startup by lazy.nvim)
-- ============================================================================
local M = {}
local project = require("util.project")

-- Default go.nvim options
local go_nvim_defaults = {
	goimports = 'goimports',
	lsp_gofumpt = false,
	build_tags = 'unit,integration,endtoendtest',
	dap_debug = false,
	diagnostic = {
		hdlr = false, -- hook diagnostic handler and send error to quickfix
		underline = true,
		virtual_text = false,
		update_in_insert = false,
		signs = true,
	},
}

M.plugins = {
	{
		'ray-x/go.nvim',
		dependencies = {
			'ray-x/guihua.lua',
			'neovim/nvim-lspconfig',
			'nvim-treesitter/nvim-treesitter',
		},
		ft = { 'go', 'gomod' },
		build = ':lua require("go.install").update_all_sync()',
		opts = project.merge_plugin_opts('ray-x/go.nvim', go_nvim_defaults),
	},
	{
		'leoluz/nvim-dap-go',
		ft = { 'go', 'gomod' },
		opts = {},
	},
	{
		'fredrikaverpil/neotest-golang',
		ft = { 'go', 'gomod' },
		dependencies = {
			'nvim-neotest/neotest',
			'leoluz/nvim-dap-go',
			'uga-rosa/utf8.nvim',
		},
	},
}

-- ============================================================================
-- PHASE 2: Runtime Configuration (runs when go buffer loads)
-- ============================================================================
local function setup()
	-- Vim Options
	vim.opt_local.expandtab = false
	vim.opt_local.tabstop = 4
	vim.opt_local.shiftwidth = 4

	-- LSP Configuration
	local helpers = require("util.ftplugin_helpers")
	helpers.setup_lsp("gopls", {
		filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
		settings = {
			gopls = {
				buildFlags = { '-tags=unit,integration,endtoend' },
				directoryFilters = { '-**/node_modules', '-**/.git' },
				analyses = {
					unusedparams = true,
					shadow = true,
				},
				staticcheck = true,
				gofumpt = true,
				usePlaceholders = true,
				completeUnimported = true,
			},
		},
	})

	-- Formatters & Linters (go.nvim handles formatting, gopls provides diagnostics)
	-- Check for project-specific overrides
	local formatters = project.get_formatters('go')
	if formatters then
		vim.b.formatters = formatters
	end

	local linters = project.get_linters('go')
	if linters then
		vim.b.linters = linters
	end

	-- Buffer-local Keymaps
	local opts = { buffer = true, silent = true }
	vim.keymap.set("n", "<leader>gt", "<cmd>GoTest<cr>", vim.tbl_extend("force", opts, { desc = "Run Go tests" }))
	vim.keymap.set("n", "<leader>gT", "<cmd>GoTestFile<cr>", vim.tbl_extend("force", opts, { desc = "Run Go test file" }))

	-- Language-specific Logic: Extract build tags from test files
	if vim.fn.expand('%'):match('_test%.go$') then
		local tags = {}
		local buf = vim.api.nvim_get_current_buf()
		local pattern = [[^//\s*[+|(go:)]*build\s\+\(.\+\)]]
		local line_count = vim.api.nvim_buf_line_count(buf)
		line_count = math.min(line_count, 10)

		for i = 0, line_count - 1 do
			local line = vim.trim(vim.api.nvim_buf_get_lines(buf, i, i + 1, false)[1] or '')
			if line:find('package', 1, true) then
				break
			end
			local t = vim.fn.substitute(line, pattern, [[\1]], '')
			if t ~= line then
				t = vim.fn.substitute(t, [[ \+]], ',', 'g')
				table.insert(tags, t)
			end
		end

		if #tags > 0 then
			vim.env.GO_TEST_FLAGS = '-tags=' .. table.concat(tags, ',')
		end
	end
end

-- Execute setup when buffer loads
setup()

-- Export for lazy.nvim to read at startup
return M
