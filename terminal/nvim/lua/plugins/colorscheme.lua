return {
  -- add gruvbox

  -- Configure LazyVim to load gruvbox
  {
    "catppuccin",
    optional = true,
    opts = {
      integrations = { blink_cmp = true },
    },
  },
}
