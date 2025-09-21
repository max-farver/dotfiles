return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.ruby_lsp = {
        mason = false,
        cmd = { vim.fn.expand("~/.asdf/shims/ruby-lsp") },
      }
    end,
  },
  {
    "tpope/vim-rails",
    dependencies = {
      "tpope/vim-bundler",
      "tpope/vim-dispatch",
    },
    lazy = true,
  },
}
