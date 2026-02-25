local add = MiniDeps.add
local now, later = MiniDeps.now, MiniDeps.later
local os_cfg = _G.Config.os
local nmap = _G.Config.nmap
local nmap_leader = _G.Config.nmap_leader

local function ensure(list, value)
	if not vim.tbl_contains(list, value) then
		table.insert(list, value)
	end
end

-- ============================================================================
-- Central Infrastructure: Shared on_attach for all LSP servers
-- ============================================================================

local function on_attach(client, bufnr)
	nmap("K", vim.lsp.buf.hover, "Hover")
	nmap_leader('cli', '<cmd>LspInfo<cr>', 'LSP Info')
	nmap_leader('clr', '<cmd>LspRestart<cr>', 'LSP Restart')
	nmap("<leader>cd", vim.diagnostic.open_float, "Line Diagnostics")
	nmap("<leader>cf", function()
		vim.lsp.buf.format({ async = true })
	end, "Format Buffer")
	nmap("<leader>ca", vim.lsp.buf.code_action, "Code Actions")
	nmap_leader('cn', function()
		return ':IncRename ' .. vim.fn.expand('<cword>')
	end, 'Rename Symbol', { expr = true })

	vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

	if client.name == "ruff_lsp" then
		client.server_capabilities.hoverProvider = false
	end
end

local function lspconfig_config()
	-- Disable diagnostic virtual_text in favor of tiny-inline-diagnostic
	vim.diagnostic.config({ virtual_text = false })

	-- Merge with cmp_nvim_lsp capabilities if available
	local capabilities = require('blink.cmp').get_lsp_capabilities(capabilities)

	-- Store capabilities globally for ftplugin files to access
	vim.g.lsp_capabilities = capabilities

	-- Set up LspAttach autocmd for on_attach functionality
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("lsp_attach_config", { clear = true }),
		callback = function(event)
			local client = vim.lsp.get_client_by_id(event.data.client_id)
			local bufnr = event.buf

			-- Call our default on_attach
			on_attach(client, bufnr)
		end,
	})
end

later(function()
	add("b0o/SchemaStore.nvim")
end)

if not os_cfg.is_linux then
	now(function()
		add({
			source = "williamboman/mason.nvim",
			hooks = {
				post_checkout = function()
					vim.schedule(function()
						pcall(vim.cmd, "MasonUpdate")
					end)
				end,
			},
		})
		local opts = { ensure_installed = {} }
		local tools = {
			"shellcheck",
			"hadolint",
			"sqlfluff",
			"tflint",
			"js-debug-adapter",
			"debugpy",
		}
		for _, tool in ipairs(tools) do
			ensure(opts.ensure_installed, tool)
		end
		require("mason").setup(opts)
	end)

	now(function()
		add({
			source = "williamboman/mason-lspconfig.nvim",
			depends = { "williamboman/mason.nvim" },
		})
		local opts = { ensure_installed = {} }
		local servers = {
			"bashls",
			"buf_ls",
			"dockerls",
			"docker_compose_language_service",
			"gopls",
			"jsonls",
			"lua_ls",
			"marksman",
			"postgres_lsp",
			"pyright",
			"ruff",
			"ruby_lsp",
			"taplo",
			"terraformls",
			"ts_ls",
			"yamlls",
		}
		for _, server in ipairs(servers) do
			ensure(opts.ensure_installed, server)
		end
		require("mason-lspconfig").setup(opts)
	end)
end

now(function()
	add({
		source = "neovim/nvim-lspconfig",
		depends = { "saghen/blink.cmp" }
	})
	lspconfig_config()
end)

later(function()
	add("stevearc/conform.nvim")
	local opts = {
		format_on_save = function(bufnr)
			-- Disable autoformat on certain filetypes
			local ignore_filetypes = { "sql", "java", "yaml", "csv", "tsv" }
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
			-- ["markdown-toc"] = {
			-- 	condition = function(_, ctx)
			-- 		for _, line in ipairs(vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)) do
			-- 			if line:find("<!%-%- toc %-%->") then
			-- 				return true
			-- 			end
			-- 		end
			-- 		return false
			-- 	end,
			-- },
			-- ["markdownlint-cli2"] = {
			-- 	condition = function(_, ctx)
			-- 		local diag = vim.tbl_filter(function(d)
			-- 			return d.source == "markdownlint-cli2"
			-- 		end, vim.diagnostic.get(ctx.buf))
			-- 		return #diag > 0
			-- 	end,
			-- },
			yamlfix = {
				env = {
					YAMLFIX_SEQUENCE_STYLE = "block_style",
					YAMLFIX_INDENT_MAPPING = "4",
					YAMLFIX_INDENT_OFFSET = "4",
					YAMLFIX_INDENT_SEQUENCE = "6",
					YAMLFIX_EXPLICIT_START = "false",
					YAMLFIX_LINE_LENGTH = "240",
					YAMLFIX_preserve_quotes = "true",
				},
			},
			sqlfluff = {
				command = "sqlfluff",
				args = { "format", "--dialect=ansi", "-" },
			},
			terraform_fmt = {
				command = "terraform",
				args = { "fmt", "-" },
			},
		},
		formatters_by_ft = {
			go = {
				'gofmt',
				-- 'gci'
			},
		},
	}
	require("conform").setup(opts)

	vim.api.nvim_create_autocmd("BufWritePre", {
		group = vim.api.nvim_create_augroup("conform_format_on_save", { clear = true }),
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
end)

later(function()
	add("mfussenegger/nvim-lint")
	local lint = require("lint")
	lint.linters_by_ft = {}

	vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
		group = vim.api.nvim_create_augroup("user_linting", { clear = true }),
		callback = function()
			local linters = vim.b.linters
			if linters then
				lint.try_lint(linters)
			end
		end,
	})
end)

now(function()
	add({
		source = "nvimtools/none-ls.nvim",
		depends = { "nvim-lua/plenary.nvim" },
	})
	local nls = require("null-ls")

	nls.setup({
		sources = {
			nls.builtins.diagnostics.markdownlint_cli2,
			nls.builtins.diagnostics.hadolint,
			nls.builtins.diagnostics.terraform_validate,
			nls.builtins.formatting.terraform_fmt,
			nls.builtins.formatting.sqlfluff, }
	})
end)
