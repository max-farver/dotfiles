local now = _G.Config.now
local add_once = _G.Config.pack_add_once or _G.Config.pack_add

now(function()
	add_once({ { src = "https://github.com/saghen/blink.cmp" } })

	local opts = {
		snippets = {
			preset = "default",
		},

		appearance = {
			-- sets the fallback highlight groups to nvim-cmp's highlight groups
			-- useful for when your theme doesn't support blink.cmp
			-- will be removed in a future release, assuming themes add support
			use_nvim_cmp_as_default = false,
			-- set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
			-- adjusts spacing to ensure icons are aligned
			nerd_font_variant = "mono",
		},
		fuzzy = { implementation = "lua" },

		completion = {
			accept = {
				-- experimental auto-brackets support
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
								local kind_icon, _, _ = require('mini.icons').get('lsp', ctx.kind)
								return kind_icon
							end,
							-- (optional) use highlights from mini.icons
							highlight = function(ctx)
								local _, hl, _ = require('mini.icons').get('lsp', ctx.kind)
								return hl
							end,
						},
						kind = {
							-- (optional) use highlights from mini.icons
							highlight = function(ctx)
								local _, hl, _ = require('mini.icons').get('lsp', ctx.kind)
								return hl
							end,
						}
					}
				},
			},
			documentation = {
				auto_show = true,
				auto_show_delay_ms = 200,
			},
		},

		-- experimental signature help support
		-- signature = { enabled = true },

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
					auto_show = function(ctx)
						return vim.fn.getcmdtype() == ":"
					end,
				},
				ghost_text = { enabled = true },
			},
		},

		keymap = {
			["<C-y>"] = { "select_and_accept" },
			['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
			['<C-e>'] = { 'hide', 'fallback' },

			['<Tab>'] = {
				'select_and_accept',
				'fallback'
			},
			['<S-Tab>'] = { 'snippet_backward', 'fallback' },

			['<Up>'] = { 'select_prev', 'fallback' },
			['<Down>'] = { 'select_next', 'fallback' },
			['<C-p>'] = { 'select_prev', 'fallback_to_mappings' },
			['<C-n>'] = { 'select_next', 'fallback_to_mappings' },

			['<C-b>'] = { 'scroll_documentation_up', 'fallback' },
			['<C-f>'] = { 'scroll_documentation_down', 'fallback' },

			['<C-k>'] = { 'show_signature', 'hide_signature', 'fallback' },
		}
	}

	require("blink.cmp").setup(opts)
end)
