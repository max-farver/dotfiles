# Neovim Configuration - CRUSH.md

## Build/Lint/Test Commands
- **Format**: `stylua lua/` (requires stylua installation)
- **Lint**: `nvim --headless -c "lua require('lazy').check()" -c q`
- **Test**: `nvim --headless -c "PlenaryBustedDirectory lua/tests/"` (if tests exist)
- **Validate config**: `nvim --headless -c "checkhealth" -c q`

## Code Style Guidelines

### Lua Conventions
- **Indentation**: 2 spaces (configured in .stylua.toml)
- **Line length**: 160 characters max
- **Quotes**: Single quotes preferred, auto-detection enabled
- **Function calls**: No parentheses for single arguments with tables
- **Naming**: snake_case for variables/functions, PascalCase for modules

### Neovim Plugin Structure
- **Plugins**: Organized in lua/plugins/ with modular imports
- **Config**: Core settings in lua/config/ (options, autocmds, keymaps)
- **Imports**: Use `require()` with relative paths for internal modules
- **Lazy loading**: Use `event`, `cmd`, `ft` keys in plugin specs

### Error Handling
- Use `pcall()` for optional operations (e.g., colorscheme)
- Wrap optional plugin requires in `pcall()` calls
- Use `vim.notify()` for user-facing messages

### Keymap Patterns
- Create helper function: `local keymap = function(mode, lhs, rhs, opts)`
- Include `desc` field for all keymaps
- Use silent=true by default, set false when needed