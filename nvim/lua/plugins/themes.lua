local function hexToRgb(c)
	c = string.lower(c)
	return { tonumber(c:sub(2, 3), 16), tonumber(c:sub(4, 5), 16), tonumber(c:sub(6, 7), 16) }
end

local function blend(foreground, background, alpha)
	alpha = type(alpha) == "string" and (tonumber(alpha, 16) / 0xff) or alpha
	local bg = hexToRgb(background)
	local fg = hexToRgb(foreground)

	local blendChannel = function(i)
		local ret = (alpha * fg[i] + ((1 - alpha) * bg[i]))
		return math.floor(math.min(math.max(0, ret), 255) + 0.5)
	end

	return string.format("#%02x%02x%02x", blendChannel(1), blendChannel(2), blendChannel(3))
end

local function darken(hex, amount, bg)
	return blend(hex, bg or bg, amount)
end

return {
	{ "catppuccin/nvim", name = "catppuccin" },
	{
		"Mofiqul/dracula.nvim",
		version = "*",
		config = function(_, opts)
			local dracula = require("dracula")
			opts.overrides = {
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
			}
			dracula.setup(opts)
		end,
	},
}
