# Quickstart Guide: Keymap Reorganization

## Prerequisites

- Neovim 0.9+ with this configuration
- Basic understanding of Vim keybindings
- Access to plugin configuration files

## Migration Overview

This guide will walk you through the process of moving custom keymap definitions from the centralized `config/keymaps.lua` file to their respective plugin configuration files to enable proper lazy loading.

## Expected Results

After completing this migration:
- **Startup Performance**: Improved startup time due to lazy loading
- **Memory Usage**: Reduced memory footprint
- **Functionality**: All existing keymaps remain functional
- **Organization**: Better code organization with keymaps co-located with their plugins

## Quick Test

### Before Migration (Baseline)
1. **Measure Current Startup Time**:
   ```bash
   nvim --startuptime before-startup.log +qa
   cat before-startup.log | tail -1
   ```

2. **Verify Current Keymaps**:
   ```lua
   :verbose map <leader>ff
   :verbose map gd
   :verbose map s
   ```

### After Migration (Validation)
1. **Measure Improved Startup Time**:
   ```bash
   nvim --startuptime after-startup.log +qa
   cat after-startup.log | tail -1
   ```

2. **Verify Keymaps Still Work**:
   - `<leader>ff` should open file picker
   - `gd` should go to definition
   - `s` should trigger Flash search
   - All other keymaps should function as before

## Usage Examples

### Example 1: File Operations (mini.files)
**Before**: Keymaps defined in `config/keymaps.lua`
**After**: Keymaps defined in `lua/plugins/mini/files.lua`

```lua
-- In lua/plugins/mini/files.lua
{
  "echasnovski/mini.files",
  version = false,
  keys = {
    { "<leader>fe", function() require('mini.files').open() end, desc = "Explorer (Root Dir)" },
    { "<leader>fE", function() require('mini.files').open(vim.uv.cwd()) end, desc = "Explorer (cwd)" },
    { "<leader>e", "<leader>fe", desc = "Explorer (Root Dir)", remap = true },
  },
  config = true,
}
```

### Example 2: LSP Navigation
**Before**: Keymaps defined in `config/keymaps.lua`
**After**: Keymaps defined in `lua/plugins/lsp.lua`

```lua
-- In lua/plugins/lsp.lua
{
  "neovim/nvim-lspconfig",
  keys = {
    { "gd", vim.lsp.buf.definition, desc = "Go to Definition" },
    { "grr", function() require('mini.pick').builtin.lsp_references() end, desc = "LSP References" },
    { "<leader>ca", vim.lsp.buf.code_action, desc = "Code Action" },
  },
}
```

### Example 3: Search and Navigation (Flash)
**Before**: Keymaps defined in `config/keymaps.lua`
**After**: Keymaps defined in `lua/plugins/general.lua` (or dedicated flash plugin)

```lua
-- In lua/plugins/general.lua
{
  "folke/flash.nvim",
  keys = {
    { "s", function() require('flash').jump() end, mode = { "n", "x", "o" }, desc = "Flash" },
    { "S", function() require('flash').treesitter() end, mode = { "n", "x", "o" }, desc = "Flash Treesitter" },
  },
  config = true,
}
```

## Migration Scenarios

### Scenario 1: Basic User Workflow
1. Open Neovim
2. Open a file: `<leader>ff`
3. Navigate to definition: `gd`
4. Search in files: `<leader>sg`
5. All operations should work without noticeable delay

### Scenario 2: Plugin-Specific Testing
1. **Git Operations**: Test all `<leader>g` keymaps
2. **LSP Operations**: Test all `g` prefixed keymaps
3. **Search Operations**: Test all `<leader>f` and `<leader>s` keymaps
4. **Window Management**: Test all `<leader>w` keymaps

### Scenario 3: Performance Validation
1. Start Neovim with `nvim --startuptime`
2. Check that startup time is reduced
3. Verify plugins load only when used
4. Check memory usage with `:lua print(collectgarbage("count"))`

## Troubleshooting

### Common Issues

1. **Keymap Not Working**:
   - Check if plugin is properly loaded
   - Verify keymap syntax in plugin file
   - Check for conflicting keymaps

2. **Plugin Not Loading**:
   - Verify loading strategy (event, command, keys)
   - Check plugin dependencies
   - Ensure plugin is properly configured

3. **Startup Time Not Improved**:
   - Check which plugins are still loading immediately
   - Verify lazy loading configuration
   - Profile startup with `:Lazy profile`

### Validation Commands

```lua
-- Check loaded plugins
:Lazy

-- Check keymaps
:verbose map <leader>

-- Check startup profile
:Lazy profile

-- Check plugin loading status
:lua print(vim.inspect(require('lazy.stats()).loaded))
```

## Success Criteria

The migration is successful when:
- ✅ All existing keymaps remain functional
- ✅ Startup time is reduced (measurable improvement)
- ✅ Plugins load only when needed
- ✅ Code is better organized and maintainable
- ✅ No breaking changes to user experience

---
*Quickstart guide completed: 2025-10-05*