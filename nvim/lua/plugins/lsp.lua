local function ensure(list, value)
	if not vim.tbl_contains(list, value) then
		table.insert(list, value)
	end
end

-- ============================================================================
-- Central Infrastructure: Shared on_attach for all LSP servers
-- ============================================================================

local function on_attach(client, bufnr)
	local function map(mode, lhs, rhs, desc, extra)
		local opts = { buffer = bufnr, desc = desc }
		if extra then
			opts = vim.tbl_extend('force', opts, extra)
		end
		vim.keymap.set(mode, lhs, rhs, opts)
	end

	map('n', 'gd', vim.lsp.buf.definition, 'Goto Definition')
	map('n', 'gD', vim.lsp.buf.declaration, 'Goto Declaration')
	map('n', 'gr', vim.lsp.buf.references, 'Goto References')
	map('n', 'gi', vim.lsp.buf.implementation, 'Goto Implementation')
	map('n', 'K', vim.lsp.buf.hover, 'Hover')
	map('n', '<leader>ca', vim.lsp.buf.code_action, 'Code Action')
	map('n', '<leader>cd', vim.diagnostic.open_float, 'Line Diagnostics')
	map('n', '<leader>cf', function()
		vim.lsp.buf.format { async = true }
	end, 'Format Buffer')
	map('n', '<leader>cr', function()
		if package.loaded['inc_rename'] then
			return ':' .. require('inc_rename').config.cmd_name .. ' ' .. vim.fn.expand '<cword>' .. '<CR>'
		end
		vim.schedule(vim.lsp.buf.rename)
		return ''
	end, 'Rename', { expr = true })
	vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'

	if client.name == 'ruff_lsp' then
		client.server_capabilities.hoverProvider = false
	end
end

local function lspconfig_config()
	-- Disable diagnostic virtual_text in favor of tiny-inline-diagnostic
	vim.diagnostic.config({ virtual_text = false })

	-- Get base capabilities
	local capabilities = vim.lsp.protocol.make_client_capabilities()

	-- Merge with cmp_nvim_lsp capabilities if available
	local has_cmp, cmp_nvim_lsp = pcall(require, 'cmp_nvim_lsp')
	if has_cmp then
		capabilities = vim.tbl_deep_extend('force', capabilities, cmp_nvim_lsp.default_capabilities())
	end

	-- Store capabilities globally for ftplugin files to access
	vim.g.lsp_capabilities = capabilities

	-- Set up LspAttach autocmd for on_attach functionality
	vim.api.nvim_create_autocmd('LspAttach', {
		group = vim.api.nvim_create_augroup('lsp_attach_config', { clear = true }),
		callback = function(event)
			local client = vim.lsp.get_client_by_id(event.data.client_id)
			local bufnr = event.buf

			-- Call our default on_attach
			on_attach(client, bufnr)
		end,
	})
end


return {
	{ 'b0o/SchemaStore.nvim', lazy = true },

	{
		'williamboman/mason.nvim',
		enabled = not require("util.os").is_linux,
		build = ':MasonUpdate',
		opts = function(_, opts)
			opts.ensure_installed = opts.ensure_installed or {}
			local tools = {
				'shellcheck',
				'hadolint',
				'sqlfluff',
				'tflint',
				'js-debug-adapter',
				'debugpy',
			}
			for _, tool in ipairs(tools) do
				ensure(opts.ensure_installed, tool)
			end
		end,
	},

	{
		'williamboman/mason-lspconfig.nvim',
		enabled = not require("util.os").is_linux,
		dependencies = { 'williamboman/mason.nvim' },
		opts = function(_, opts)
			opts.ensure_installed = opts.ensure_installed or {}
			-- LSP servers to ensure are installed
			local servers = {
				'bashls',
				'dockerls',
				'docker_compose_language_service',
				'gopls',
				'jsonls',
				'lua_ls',
				'marksman',
				'postgres_lsp',
				'pyright',
				'ruff',
				'taplo',
				'terraformls',
				'ts_ls',
				'yamlls',
			}
			for _, server in ipairs(servers) do
				ensure(opts.ensure_installed, server)
			end
		end,
	},

	-- LspConfig for linux
	{
		'neovim/nvim-lspconfig',
		config = lspconfig_config,
	},

	{
		'stevearc/conform.nvim',
		event = { "BufWritePre" },
		opts = {
			format_on_save = function(bufnr)
				-- Disable autoformat on certain filetypes
				local ignore_filetypes = { "sql", "java" }
				if vim.tbl_contains(ignore_filetypes, vim.bo[bufnr].filetype) then
					return
				end
				-- Disable with a global or buffer-local variable
				if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
					return
				end
				-- ...additional logic...
				return { timeout_ms = 500, lsp_format = "fallback" }
			end,
			formatters = {
				['markdown-toc'] = {
					condition = function(_, ctx)
						for _, line in ipairs(vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)) do
							if line:find '<!%-%- toc %-%->' then
								return true
							end
						end
						return false
					end,
				},
				['markdownlint-cli2'] = {
					condition = function(_, ctx)
						local diag = vim.tbl_filter(function(d)
							return d.source == 'markdownlint-cli2'
						end, vim.diagnostic.get(ctx.buf))
						return #diag > 0
					end,
				},
				yamlfix = {
					env = {
						YAMLFIX_SEQUENCE_STYLE = 'block_style',
						YAMLFIX_INDENT_MAPPING = '4',
						YAMLFIX_INDENT_OFFSET = '4',
						YAMLFIX_INDENT_SEQUENCE = '6',
						YAMLFIX_EXPLICIT_START = 'false',
						YAMLFIX_LINE_LENGTH = '240',
						YAMLFIX_preserve_quotes = 'true',
					},
				},
				sqlfluff = {
					command = 'sqlfluff',
					args = { 'format', '--dialect=ansi', '-' },
				},
				terraform_fmt = {
					command = 'terraform',
					args = { 'fmt', '-' },
				},
			},
			formatters_by_ft = {}, -- Start empty, ftplugins populate via buffer vars
		},
		config = function(_, opts)
			require("conform").setup(opts)

			-- Read formatters from buffer variable set by ftplugin
			vim.api.nvim_create_autocmd("BufWritePre", {
				group = vim.api.nvim_create_augroup('conform_format_on_save', { clear = true }),
				callback = function(args)
					local formatters = vim.b[args.buf].formatters
					if formatters then
						require("conform").format({
							bufnr = args.buf,
							formatters = formatters,
							lsp_format = "fallback",
							timeout_ms = 500,
						})
					end
				end,
			})
		end,
	},

	{
		'mfussenegger/nvim-lint',
		event = { 'BufReadPost', 'BufNewFile' },
		config = function()
			local lint = require 'lint'
			lint.linters_by_ft = {} -- Start empty

			-- Read linters from buffer variable set by ftplugin
			vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
				group = vim.api.nvim_create_augroup('user_linting', { clear = true }),
				callback = function()
					local linters = vim.b.linters
					if linters then
						lint.try_lint(linters)
					end
				end,
			})
		end,
	},

	{
		'nvimtools/none-ls.nvim',
		dependencies = { 'nvim-lua/plenary.nvim' },
		opts = function(_, opts)
			local nls = require 'null-ls'
			opts = opts or {}
			opts.sources = opts.sources or {}
			local sources = {
				nls.builtins.diagnostics.markdownlint_cli2,
				nls.builtins.diagnostics.hadolint,
				nls.builtins.diagnostics.terraform_validate,
				nls.builtins.formatting.terraform_fmt,
				nls.builtins.formatting.sqlfluff,
			}
			for _, source in ipairs(sources) do
				table.insert(opts.sources, source)
			end
			return opts
		end,
		config = function(_, opts)
			require('null-ls').setup(opts)
		end,
	},
}
