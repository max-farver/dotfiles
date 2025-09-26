local function have(path)
	local config_dir = vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. '/.config')
	return vim.uv.fs_stat(config_dir .. '/' .. path) ~= nil
end

return {
	{
		'neovim/nvim-lspconfig',
		opts = function(_, opts)
			opts.servers = opts.servers or {}
			opts.servers.bashls = opts.servers.bashls or {}
		end,
	},
	{
		'williamboman/mason.nvim',
		enabled = not require("config.os").is_linux,
		opts = function(_, opts)
			opts.ensure_installed = opts.ensure_installed or {}
			if not vim.tbl_contains(opts.ensure_installed, 'shellcheck') then
				table.insert(opts.ensure_installed, 'shellcheck')
			end
		end,
	},
	{
		'nvim-treesitter/nvim-treesitter',
		opts = function(_, opts)
			if type(opts.ensure_installed) == 'table' then
				local function add(lang)
					if not vim.tbl_contains(opts.ensure_installed, lang) then
						table.insert(opts.ensure_installed, lang)
					end
				end
				add 'git_config'
				if have 'hypr' then
					add 'hyprlang'
				end
				if have 'fish' then
					add 'fish'
				end
				if have 'rofi' or have 'wofi' then
					add 'rasi'
				end
			end
			vim.filetype.add {
				extension = { rasi = 'rasi', rofi = 'rasi', wofi = 'rasi' },
				filename = { vifmrc = 'vim' },
				pattern = {
					['.*/waybar/config'] = 'jsonc',
					['.*/mako/config'] = 'dosini',
					['.*/kitty/.+%.conf'] = 'kitty',
					['.*/hypr/.+%.conf'] = 'hyprlang',
					['%.env%.[%w_.-]+'] = 'sh',
				},
			}
			vim.treesitter.language.register('bash', 'kitty')
		end,
	},
}
