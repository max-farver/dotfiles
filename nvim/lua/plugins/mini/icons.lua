return {
  "nvim-mini/mini.icons",
  lazy = true,
  opts = {
    file = {
      [".keep"] = { glyph = "󰊢" },
      ["devcontainer.json"] = { glyph = "" },
    },
    filetype = {
      dotenv = { glyph = "" },
    },
  },
  init = function()
    package.preload["nvim-web-devicons"] = function()
      require("mini.icons").mock_nvim_web_devicons()
      return package.loaded["nvim-web-devicons"]
    end
  end,
}

