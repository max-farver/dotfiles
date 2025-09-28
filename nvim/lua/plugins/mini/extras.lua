return {
  "nvim-mini/mini.extra",
  version = "*",
  lazy = false,
  config = function()
    local ok, extra = pcall(require, 'mini.extra')
    if ok then
      extra.setup()
    end
  end,
}
