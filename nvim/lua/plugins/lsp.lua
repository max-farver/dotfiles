local function schemastore(fn)
	local ok, store = pcall(require, 'schemastore')
	if ok then
		return fn(store)
	end
end

local function ensure(list, value)
	if not vim.tbl_contains(list, value) then
		table.insert(list, value)
	end
end

local servers = {
	bashls = {},
	dockerls = {},
	docker_compose_language_service = {},
	jsonls = {
		settings = {
			json = {
				schemas = schemastore(function(store)
					return store.json.schemas()
				end),
				validate = { enable = true },
			},
		},
	},
	lua_ls = {
		settings = {
			Lua = {
				completion = { callSnippet = 'Replace' },
				diagnostics = { globals = { 'vim' } },
				workspace = { checkThirdParty = false },
			},
		},
	},
	marksman = {},
	nil_ls = {},
	postgres_lsp = {},
	pyright = {},
	ruff_lsp = {
		cmd_env = { RUFF_TRACE = 'messages' },
		init_options = {
			settings = {
				logLevel = 'error',
			},
		},
	},
	taplo = {},
	terraformls = {},
	tsserver = {},
	yamlls = {
		settings = {
			yaml = {
				keyOrdering = false,
				schemaStore = { enable = false, url = '' },
				schemas = schemastore(function(store)
					return store.yaml.schemas()
				end),
			},
		},
	},
}

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

local function lspconfig_config(_, opts)
	-- Use lspconfig.configs to avoid deprecated require('lspconfig') framework
	local configs = require 'lspconfig.configs'
	local capabilities = vim.lsp.protocol.make_client_capabilities()

	for name, server_opts in pairs(opts.servers) do
		server_opts = vim.tbl_deep_extend('force', {}, server_opts)
		server_opts.capabilities = vim.tbl_deep_extend('force', {}, capabilities,
			server_opts.capabilities or {})
		local original_attach = server_opts.on_attach
		server_opts.on_attach = function(client, bufnr)
			on_attach(client, bufnr)
			if original_attach then
				original_attach(client, bufnr)
			end
		end
		-- Ensure the server configuration is loaded without requiring the deprecated framework
		pcall(require, 'lspconfig.server_configurations.' .. name)
		if configs[name] and type(configs[name].setup) == 'function' then
			configs[name].setup(server_opts)
		end
		vim.lsp.enable(name)
	end
end


return {
	{ 'b0o/SchemaStore.nvim', lazy = true },

	{
		'williamboman/mason.nvim',
		enabled = not require("config.os").is_linux,
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
		enabled = not require("config.os").is_linux,
		dependencies = { 'williamboman/mason.nvim' },
		opts = function(_, opts)
			opts.ensure_installed = opts.ensure_installed or {}
			for name in pairs(servers) do
				ensure(opts.ensure_installed, name)
			end
		end,
	},

	-- LspConfig for linux
	{
		'neovim/nvim-lspconfig',
		enabled = not require("config.os").is_linux,
		dependencies = {
			'williamboman/mason-lspconfig.nvim',
		},
		opts = {
			servers = servers,
		},
		config = lspconfig_config,
	},
	-- LspConfig for any mac
	{
		'neovim/nvim-lspconfig',
		enabled = require("config.os").is_linux,
		opts = {
			servers = servers,
		},
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
			formatters_by_ft = {
				markdown = { 'prettier', 'markdownlint-cli2', 'markdown-toc' },
				['markdown.mdx'] = { 'prettier', 'markdownlint-cli2', 'markdown-toc' },
				sql = { 'sqlfluff' },
				mysql = { 'sqlfluff' },
				plsql = { 'sqlfluff' },
				terraform = { 'terraform_fmt' },
				tf = { 'terraform_fmt' },
				['terraform-vars'] = { 'terraform_fmt' },
				yaml = { 'yamlfix' },
			},
		},
	},

	{
		'mfussenegger/nvim-lint',
		event = { 'BufReadPost', 'BufNewFile' },
		opts = function(_, opts)
			opts.linters_by_ft = opts.linters_by_ft or {}
			opts.linters_by_ft.markdown = opts.linters_by_ft.markdown or { 'markdownlint-cli2' }
			opts.linters_by_ft.yaml = opts.linters_by_ft.yaml or { 'yamllint' }
			opts.linters_by_ft.dockerfile = opts.linters_by_ft.dockerfile or { 'hadolint' }
			opts.linters_by_ft.terraform = opts.linters_by_ft.terraform or { 'terraform_validate' }
			opts.linters_by_ft.tf = opts.linters_by_ft.tf or { 'terraform_validate' }
		end,
		config = function(_, opts)
			local lint = require 'lint'
			lint.linters_by_ft = opts.linters_by_ft or {}
			vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
				group = vim.api.nvim_create_augroup('user_linting', { clear = true }),
				callback = function()
					lint.try_lint()
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
