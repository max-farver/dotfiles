local now, later = MiniDeps.now, MiniDeps.later
local add = MiniDeps.add
local now_if_args = _G.Config.now_if_args
local root = _G.Config.root.get

local map = _G.Config.map
local nmap_leader = _G.Config.nmap_leader

now(function()
	add('saghen/blink.cmp')

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
			-- adding any nvim-cmp sources here will enable them
			-- with blink.compat
			default = { "lsp", "path", "snippets", "buffer" },
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
			preset = "super-tab",
			["<C-y>"] = { "select_and_accept" },
		}
	}

	require("blink.cmp").setup(opts)
end)
