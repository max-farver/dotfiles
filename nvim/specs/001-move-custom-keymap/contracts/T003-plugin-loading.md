# Contract Test: Plugin Loading

**Requirement**: FR-002 - System MUST ensure that plugins with custom keymaps load only when needed, not at startup time
**Description**: Verify that plugins load only when needed, not at startup time

## Preconditions
- Migrated configuration with keymaps in plugin files
- Neovim with lazy.nvim plugin manager
- Access to lazy.nvim status commands
- Test file with LSP support (for LSP plugin testing)

## Test Steps
1. **Check Initial Plugin Loading Status**:
   ```lua
   :Lazy
   ```
   Note which plugins are loaded at startup

2. **Test File Explorer Plugin Loading** (mini.files):
   - Verify mini.files is not loaded at startup
   - Press `<leader>fe` to open file explorer
   - Check `:Lazy` again to verify mini.files is now loaded

3. **Test Flash Plugin Loading**:
   - Verify flash.nvim is not loaded at startup
   - Press `s` to trigger Flash search
   - Check `:Lazy` to verify flash.nvim is now loaded

4. **Test LSP Plugin Loading**:
   - Open a file with language server support (e.g., .lua, .py)
   - Verify LSP plugins are not loaded immediately
   - Press `gd` to go to definition
   - Check `:Lazy` to verify LSP plugins are now loaded

5. **Test Git Plugin Loading**:
   - Verify git-related plugins are not loaded at startup
   - Press `<leader>gs` to stage hunk
   - Check `:Lazy` to verify git plugins are now loaded

6. **Test Search Plugin Loading**:
   - Verify search plugins are not loaded at startup
   - Press `<leader>sg` to open grug-far search
   - Check `:Lazy` to verify search plugins are now loaded

7. **Test Yanky Plugin Loading**:
   - Verify yanky.nvim is not loaded at startup
   - Press `y` to yank some text
   - Check `:Lazy` to verify yanky.nvim is now loaded

8. **Verify Loading Triggers**:
   - Check that plugins load only when their specific keymaps are used
   - Verify no plugins load without user interaction
   - Ensure essential plugins still load appropriately

## Expected Results
- No plugins with keymaps load at startup
- Plugins load immediately when their keymaps are triggered
- Loading is fast and seamless to the user
- No delays or errors when plugins load on-demand
- Essential plugins (core functionality) load appropriately

## Validation Method
1. **Status Command Verification**:
   - Use `:Lazy` to check plugin loading status
   - Verify "not loaded" status for plugins before keymap use
   - Verify "loaded" status after keymap use

2. **Loading Time Measurement**:
   - Time how long it takes for plugins to load when triggered
   - Ensure loading time is < 100ms for good user experience
   - Check for any noticeable delays

3. **Event Log Analysis**:
   - Check lazy.nvim logs for loading events
   - Verify correct loading triggers are used
   - Ensure no unwanted loading events occur

## Success Criteria
- ✅ No plugin with keymaps loads at startup
- ✅ Plugins load within 100ms when their keymaps are triggered
- ✅ Loading is seamless without user-perceivable delays
- ✅ Essential functionality remains available when needed
- ✅ No errors occur during on-demand loading

## Loading Strategy Validation
- **Event-based**: Plugins load on VeryLazy, InsertEnter, etc.
- **Command-based**: Plugins load when their commands are executed
- **Key-based**: Plugins load when their keymaps are pressed
- **File-type based**: Plugins load for specific file types

---
*Contract test completed: 2025-10-05*