return {
	'nvim-mini/mini.starter',
	version = '*',
	enabled = false,
	config = function()
		require('mini.starter').setup()
	end,
}
