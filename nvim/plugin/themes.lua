local add = MiniDeps.add
local now = MiniDeps.now

local function hex_to_rgb(c)
	c = string.lower(c)
	return { tonumber(c:sub(2, 3), 16), tonumber(c:sub(4, 5), 16), tonumber(c:sub(6, 7), 16) }
end

local function blend(foreground, background, alpha)
	alpha = type(alpha) == "string" and (tonumber(alpha, 16) / 0xff) or alpha
	local bg = hex_to_rgb(background)
	local fg = hex_to_rgb(foreground)

	local function channel(i)
		local ret = (alpha * fg[i] + ((1 - alpha) * bg[i]))
		return math.floor(math.min(math.max(0, ret), 255) + 0.5)
	end

	return string.format("#%02x%02x%02x", channel(1), channel(2), channel(3))
end

local function darken(hex, amount, bg)
	return blend(hex, bg, amount)
end

now(function()
	add({ source = "projekt0n/github-nvim-theme", name = "github-theme" })
	require("github-theme").setup({})
end)

now(function()
	add("Mofiqul/dracula.nvim")
	local dracula = require("dracula")
	dracula.setup({
		overrides = {
			DiffAdd = { bg = darken(dracula.colors().bright_green, 0.15, dracula.colors().bg) },
			DiffDelete = { fg = darken(dracula.colors().bright_red, 0.15, dracula.colors().bg) },
			DiffChange = { bg = darken(dracula.colors().comment, 0.15, dracula.colors().bg) },
			DiffText = { bg = darken(dracula.colors().comment, 0.50, dracula.colors().bg) },
			illuminatedWord = { bg = darken(dracula.colors().comment, 0.65, dracula.colors().bg) },
			illuminatedCurWord = { bg = darken(dracula.colors().comment, 0.65, dracula.colors().bg) },
			IlluminatedWordText = { bg = darken(dracula.colors().comment, 0.65, dracula.colors().bg) },
			IlluminatedWordRead = { bg = darken(dracula.colors().comment, 0.65, dracula.colors().bg) },
			IlluminatedWordWrite = { bg = darken(dracula.colors().comment, 0.65, dracula.colors().bg) },
			MiniPickMatchCurrent = { bg = dracula.colors().selection },
			MiniFilesBorder = { fg = dracula.colors().fg, bg = dracula.colors().bg },
			MiniFilesBorderModified = { fg = dracula.colors().orange, bg = dracula.colors().bg },
			MiniFilesCursorLine = { bg = dracula.colors().selection },
			MiniFilesDirectory = { fg = dracula.colors().cyan, bg = dracula.colors().bg },
			MiniFilesFile = { fg = dracula.colors().fg, bg = dracula.colors().bg },
			MiniFilesNormal = { fg = dracula.colors().fg, bg = dracula.colors().bg },
			MiniFilesTitle = { fg = dracula.colors().purple, bg = dracula.colors().bg, bold = true },
			MiniFilesTitleFocused = { fg = dracula.colors().cyan, bg = dracula.colors().bg, bold = true },
		},
	})

	vim.cmd("colorscheme dracula")
end)
