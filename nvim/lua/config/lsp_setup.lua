local M = {}

function M.setup()
  local ok, lspconfig = pcall(require, 'lspconfig')
  if not ok then return end

  local capabilities = vim.lsp.protocol.make_client_capabilities()
  pcall(function()
    local cmp = require('cmp_nvim_lsp')
    capabilities = cmp.default_capabilities(capabilities)
  end)

  local function on_attach(_, bufnr)
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
    end
    map('n', 'gd', vim.lsp.buf.definition, 'Goto Definition')
    map('n', 'gr', vim.lsp.buf.references, 'Goto References')
    map('n', 'gI', vim.lsp.buf.implementation, 'Goto Implementation')
    map('n', 'K', vim.lsp.buf.hover, 'Hover')
    map('n', '<leader>cr', vim.lsp.buf.rename, 'LSP Rename')
    map({'n','v'}, '<leader>ca', vim.lsp.buf.code_action, 'LSP Code Action')
  end

  local servers = {
    lua_ls = {
      settings = {
        Lua = {
          workspace = { checkThirdParty = false },
          telemetry = { enable = false },
          diagnostics = { globals = { 'vim' } },
        },
      },
    },
    gopls = {},
    pyright = {},
    tsserver = {},
  }

  for name, cfg in pairs(servers) do
    cfg.capabilities = capabilities
    cfg.on_attach = on_attach
    lspconfig[name].setup(cfg)
  end
end

return M

