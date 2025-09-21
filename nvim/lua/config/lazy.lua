local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { import = "plugins.core" },
    { import = "plugins.games" },
    { import = "plugins.general" },
    { import = "plugins.git" },
    { import = "plugins.go" },
    { import = "plugins.lsp" },
    { import = "plugins.markdown" },
    { import = "plugins.mini.misc" },
    { import = "plugins.mini.pick" },
    { import = "plugins.mini.animate" },
    { import = "plugins.mini.basics" },
    { import = "plugins.mini.files" },
    { import = "plugins.mini.completion" },
    { import = "plugins.mini.snippets" },
    { import = "plugins.mini.clue" },
    { import = "plugins.mini.notify" },
    { import = "plugins.mini.icons" },
    { import = "plugins.mini.hipatterns" },
    { import = "plugins.mini.operators" },
    { import = "plugins.mini.move" },
    { import = "plugins.mini.surround" },
    { import = "plugins.mini.pairs" },
    { import = "plugins.mini.ai" },
    { import = "plugins.dot" },
    { import = "plugins.neotest" },
    { import = "plugins.nvim-ufo" },
    { import = "plugins.python" },
    { import = "plugins.sql" },
    { import = "plugins.ruby" },
    { import = "plugins.snacks" },
    { import = "plugins.vscode" },
    { import = "plugins.themes" },
    { import = "plugins.ui" },
  },
  defaults = {
    lazy = true,
    version = false,
  },
  install = {
    colorscheme = { "dracula", "tokyonight" },
  },
  checker = {
    enabled = true,
    notify = false,
  },
  change_detection = {
    notify = false,
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
