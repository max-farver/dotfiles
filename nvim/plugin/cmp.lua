local add_once = _G.Config.add_once

local cmp_loaded = false

local function setup_cmp()
	if cmp_loaded then
		return
	end
	cmp_loaded = true

	add_once({ { src = "https://github.com/saghen/blink.cmp" } })

	local opts = {
		snippets = {
			preset = "default",
		},

		appearance = {
			use_nvim_cmp_as_default = false,
			nerd_font_variant = "mono",
		},
		fuzzy = { implementation = "lua" },

		completion = {
			accept = {
				auto_brackets = {
					enabled = true,
				},
			},
			menu = {
				draw = {
					treesitter = { "lsp" },
					components = {
						kind_icon = {
							text = function(ctx)
								local kind_icon, _, _ = require("mini.icons").get("lsp", ctx.kind)
								return kind_icon
							end,
							highlight = function(ctx)
								local _, hl, _ = require("mini.icons").get("lsp", ctx.kind)
								return hl
							end,
						},
						kind = {
							highlight = function(ctx)
								local _, hl, _ = require("mini.icons").get("lsp", ctx.kind)
								return hl
							end,
						},
					},
				},
			},
			documentation = {
				auto_show = true,
				auto_show_delay_ms = 200,
			},
		},

		sources = {
			default = { "lsp", "path", "buffer" },
		},

		cmdline = {
			enabled = true,
			keymap = {
				preset = "cmdline",
				["<Right>"] = false,
				["<Left>"] = false,
			},
			completion = {
				list = { selection = { preselect = false } },
				menu = {
					auto_show = function()
						return vim.fn.getcmdtype() == ":"
					end,
				},
				ghost_text = { enabled = true },
			},
		},

		keymap = {
			["<C-y>"] = { "select_and_accept" },
			["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
			["<C-e>"] = { "hide", "fallback" },
			["<Tab>"] = { "select_and_accept", "fallback" },
			["<S-Tab>"] = { "snippet_backward", "fallback" },
			["<Up>"] = { "select_prev", "fallback" },
			["<Down>"] = { "select_next", "fallback" },
			["<C-p>"] = { "select_prev", "fallback_to_mappings" },
			["<C-n>"] = { "select_next", "fallback_to_mappings" },
			["<C-b>"] = { "scroll_documentation_up", "fallback" },
			["<C-f>"] = { "scroll_documentation_down", "fallback" },
			["<C-k>"] = { "show_signature", "hide_signature", "fallback" },
		},
	}

	local ok_cmp, cmp = pcall(require, "blink.cmp")
	if ok_cmp then
		cmp.setup(opts)
	end
end

vim.api.nvim_create_autocmd("InsertEnter", {
	group = vim.api.nvim_create_augroup("cmp_lazy_load_insert", { clear = true }),
	once = true,
	callback = setup_cmp,
})

vim.api.nvim_create_autocmd("CmdlineEnter", {
	group = vim.api.nvim_create_augroup("cmp_lazy_load_cmdline", { clear = true }),
	callback = function()
		if vim.fn.getcmdtype() == ":" then
			setup_cmp()
		end
	end,
})
