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
  { "nyoom-engineering/oxocarbon.nvim", name = "oxocarbon" },
  { "catppuccin/nvim", name = "catppuccin" },
  {
    "projekt0n/github-nvim-theme",
    name = "github-theme",
    config = function()
      require("github-theme").setup({
        -- ...
      })

      vim.cmd("colorscheme github_dark")
    end,
  },
  {
    "rebelot/kanagawa.nvim",
    opts = {
      compile = false, -- enable compilation of the colorscheme
      theme = "wave", -- set theme to wave
      background = { -- set background to dark
        dark = "wave",
        light = "lotus",
      },
      overrides = function(colors)
        local theme = colors.theme
        return {
          Pmenu = { fg = theme.ui.shade0, bg = theme.ui.bg_p1 }, -- add `blend = vim.o.pumblend` to enable transparency
          PmenuSel = { fg = "NONE", bg = theme.ui.bg_p2 },
          PmenuSbar = { bg = theme.ui.bg_m1 },
          PmenuThumb = { bg = theme.ui.bg_p2 },
        }
      end,
    },
  },
  {
    "Mofiqul/dracula.nvim",
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
      }
      dracula.setup(opts)
    end,
  },
}
