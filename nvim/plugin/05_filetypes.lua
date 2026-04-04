-- Add custom file types here that aren't automatically detected
vim.filetype.add({
	filename = {
		vifmrc = 'vim',
	},
	extension = {
		nix = 'nix',
	},
	pattern = {
		['%.env%.[%w_.-]+'] = 'sh',
	},
})
