local palette = {
	base00 = '#282a36', -- bg
	base01 = '#282a36',
	base02 = '#44475a',
	base03 = '#6272a4',
	base04 = '#c0c0d0',
	base05 = '#f8f8f2', -- fg
	base06 = '#f1f1f6',
	base07 = '#ffffff',
	base08 = '#8be9fd', -- red
	base09 = '#ff5555', -- orange
	base0A = '#bd93f9', -- yellow
	base0B = '#f1fa8c', -- green
	base0C = '#ffb86c', -- cyan
	base0D = '#50fa7b', -- purple
	base0E = '#ff79c6', -- pink
	base0F = '#b294bb',
}

return {
	"nvim-mini/mini.base16",
	version = "*",
	config = function()
		local ok, MiniBase16 = pcall(require, 'mini.base16')
		if not ok then
			vim.notify('mini.base16 not available', vim.log.levels.WARN)
			return
		end

		-- Use the mini.base16 API: supply palette and use_cterm
		MiniBase16.setup({
			palette = palette,
			use_cterm = true,
			plugins = {
				default = true,
				['nvim-mini/mini.nvim'] = true,
				-- ['lewis6991/gitsigns.nvim'] = true,
			},
		})

		-- Override NormalFloat to use base00 (background) with base05 foreground
		-- pcall(vim.api.nvim_set_hl, 0, 'NormalFloat', { fg = palette.base05, bg = palette.base00 })

		-- set colorscheme name so other logic recognizes it
		vim.g.colors_name = "dracula_base16"
	end,
}
