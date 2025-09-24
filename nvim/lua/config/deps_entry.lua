-- Entry helpers to try mini.deps loading without switching init.lua
local M = {}

-- Native mini.deps entry: require modules so they self-register using MiniDeps.add/now/later
function M.load_all_native()
  require('config.deps').setup()
  local groups = {
    'plugins.core',
    'plugins.games',
    'plugins.general',
    'plugins.git',
    'plugins.go',
    'plugins.lsp',
    'plugins.markdown',
    'plugins.mini.misc',
    'plugins.mini.pick',
    'plugins.mini.animate',
    'plugins.mini.basics',
    'plugins.mini.files',
    'plugins.mini.completion',
    'plugins.mini.snippets',
    'plugins.mini.clue',
    'plugins.mini.notify',
    'plugins.mini.icons',
    'plugins.mini.hipatterns',
    'plugins.mini.operators',
    'plugins.mini.move',
    'plugins.mini.surround',
    'plugins.mini.pairs',
    'plugins.mini.ai',
    'plugins.dot',
    'plugins.neotest',
    'plugins.nvim-ufo',
    'plugins.python',
    'plugins.sql',
    'plugins.ruby',
    'plugins.snacks',
    'plugins.vscode',
    'plugins.themes',
    'plugins.ui',
  }
  local ok, MiniDeps = pcall(require, 'mini.deps')
  if not ok then return end
  MiniDeps.now(function()
    for _, g in ipairs(groups) do pcall(require, g) end
  end)
end

return M
