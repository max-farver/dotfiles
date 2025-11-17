local add = MiniDeps.add
local now = MiniDeps.now
local nmap_leader = _G.Config.nmap_leader

local Theme = require("util.theme")

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
	add("max-farver/dracula.nvim")
	local dracula = require("dracula")
	local colors = dracula.colors()
	dracula.setup({
		overrides = {
			DiffAdd = { bg = darken(colors.bright_green, 0.15, colors.bg) },
			DiffDelete = { fg = darken(colors.bright_red, 0.15, colors.bg) },
			DiffChange = { bg = darken(colors.comment, 0.15, colors.bg) },
			DiffText = { bg = darken(colors.comment, 0.50, colors.bg) },
			illuminatedWord = { bg = darken(colors.comment, 0.65, colors.bg) },
			illuminatedCurWord = { bg = darken(colors.comment, 0.65, colors.bg) },
			IlluminatedWordText = { bg = darken(colors.comment, 0.65, colors.bg) },
			IlluminatedWordRead = { bg = darken(colors.comment, 0.65, colors.bg) },
			IlluminatedWordWrite = { bg = darken(colors.comment, 0.65, colors.bg) },
			MiniPickMatchCurrent = { bg = colors.selection },
			MiniFilesBorder = { fg = colors.fg, bg = colors.bg },
			MiniFilesBorderModified = { fg = colors.orange, bg = colors.bg },
			MiniFilesCursorLine = { bg = colors.selection },
			MiniFilesDirectory = { fg = colors.cyan, bg = colors.bg },
			MiniFilesFile = { fg = colors.fg, bg = colors.bg },
			MiniFilesNormal = { fg = colors.fg, bg = colors.bg },
			MiniFilesTitle = { fg = colors.purple, bg = colors.bg, bold = true },
			MiniFilesTitleFocused = { fg = colors.cyan, bg = colors.bg, bold = true },
		},
	})
end)

now(function()
	Theme.load_last()
end)

_G.Config.new_autocmd("ColorScheme", "*", function(event)
	Theme.on_colorscheme(event.match)
end, "Persist preferred theme variant")

vim.api.nvim_create_user_command("ThemeDark", function()
	Theme.apply("dark")
end, { desc = "Switch to the default dark theme" })

vim.api.nvim_create_user_command("ThemeLight", function()
	Theme.apply("light")
end, { desc = "Switch to the default light theme" })

vim.api.nvim_create_user_command("ThemeToggle", function()
	Theme.toggle()
end, { desc = "Toggle between light/dark themes" })

nmap_leader('ub', '<Cmd>ThemeToggle<CR>', 'Toggle Dark Mode')
