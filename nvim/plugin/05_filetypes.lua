-- Add custom file types here that aren't automatically detected
vim.filetype.add({
	filename = {
		['*.nix'] = 'nix',
		vifmrc = 'vim'
	},
	pattern = {
		['%.env%.[%w_.-]+'] = 'sh',
	},
})
