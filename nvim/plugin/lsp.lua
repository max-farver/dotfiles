local add_once = _G.Config.add_once
local now, later = _G.Config.now, _G.Config.later
local os_cfg = _G.Config.os

local function ensure(list, value)
	if not vim.tbl_contains(list, value) then
		table.insert(list, value)
	end
end

-- ============================================================================
-- Central Infrastructure: Shared on_attach for all LSP servers
-- ============================================================================

local function on_attach(client, bufnr)
	local function bmap(mode, lhs, rhs, desc, opts)
		opts = opts or {}
		opts.buffer = bufnr
		opts.silent = opts.silent ~= false
		opts.desc = desc or opts.desc
		vim.keymap.set(mode, lhs, rhs, opts)
	end

	bmap("n", "K", vim.lsp.buf.hover, "Hover")
	bmap("n", "<leader>cli", "<cmd>checkhealth vim.lsp<cr>", "LSP Info")
	bmap("n", "<leader>clr", "<cmd>lsp restart<cr>", "LSP Restart")
	bmap("n", "<leader>cd", vim.diagnostic.open_float, "Line Diagnostics")
	bmap("n", "<leader>cf", function()
		vim.lsp.buf.format({ async = true })
	end, "Format Buffer")
	bmap("n", "<leader>ca", vim.lsp.buf.code_action, "Code Actions")
	bmap("n", "<leader>cn", vim.lsp.buf.rename, "Rename Symbol")

	vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

	if client.name == "ruff" then
		client.server_capabilities.hoverProvider = false
	end
end

local function lspconfig_config()
	-- Disable diagnostic virtual_text in favor of tiny-inline-diagnostic
	vim.diagnostic.config({ virtual_text = false })

	local capabilities = vim.lsp.protocol.make_client_capabilities()
	local ok_blink, blink = pcall(require, "blink.cmp")
	if ok_blink and type(blink.get_lsp_capabilities) == "function" then
		capabilities = blink.get_lsp_capabilities(capabilities)
	end

	-- Store capabilities globally for ftplugin files to access
	_G.Config.lsp_capabilities = capabilities

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
	add_once({ { src = "https://github.com/b0o/SchemaStore.nvim" } })
end)

if not os_cfg.is_linux then
	now(function()
		add_once({
			{ src = "https://github.com/williamboman/mason.nvim" },
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
		add_once({
			{ src = "https://github.com/neovim/nvim-lspconfig" },
			{ src = "https://github.com/williamboman/mason-lspconfig.nvim" },
		})
		local opts = { ensure_installed = {} }
		local servers = {
			"bashls",
			"buf_ls",
			"clangd",
			"cmake",
			"dockerls",
			"docker_compose_language_service",
			"gopls",
			"jsonls",
			"lua_ls",
			-- "marksman",
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
	lspconfig_config()
end)

later(function()
	add_once({ { src = "https://github.com/stevearc/conform.nvim" } })
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
			terraform = { "terraform_fmt" },
			tf = { "terraform_fmt" },
			["terraform-vars"] = { "terraform_fmt" },
			sql = { "sqlfluff" },
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
	add_once({ { src = "https://github.com/mfussenegger/nvim-lint" } })
	local lint = require("lint")
	lint.linters_by_ft = {
		dockerfile = { "hadolint" },
		markdown = { "markdownlint-cli2" },
		terraform = { "terraform_validate" },
	}

	vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
		group = vim.api.nvim_create_augroup("user_linting", { clear = true }),
		callback = function()
			-- Use buffer-local linters if set (from ftplugin), otherwise use linters_by_ft
			local linters = vim.b.linters
			if linters then
				lint.try_lint(linters)
			else
				lint.try_lint()
			end
		end,
	})
end)

