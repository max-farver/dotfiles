return {
	{
		'nvim-mini/mini.misc',
		opts = function()
			return { make_global = { 'put', 'put_text', 'stat_summary', 'bench_time' } }
		end,
		config = function(_, opts)
			local MiniMisc = require('mini.misc')
			MiniMisc.setup(opts)
			MiniMisc.setup_auto_root()
			MiniMisc.setup_termbg_sync()
		end,
	},
}
