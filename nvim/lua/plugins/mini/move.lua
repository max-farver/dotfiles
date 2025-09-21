return {
  "nvim-mini/mini.move",
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    mappings = {
      left = "<M-Left>",
      right = "<M-Right>",
      down = "<M-Down>",
      up = "<M-Up>",
      line_left = "<M-Left>",
      line_right = "<M-Right>",
      line_down = "<M-Down>",
      line_up = "<M-Up>",
    },
  },
}
