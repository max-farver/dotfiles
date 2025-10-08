# Contract Test: Keymap Functionality

**Requirement**: FR-003 - Users MUST be able to access all existing keybinding functionality after reorganization
**Description**: Verify that all existing keymaps remain functional after migration from centralized keymap file to plugin files

## Preconditions
- Neovim configuration has been migrated to move keymaps from config/keymaps.lua to plugin files
- All plugin files have been updated with their respective keymaps
- Migration process is complete

## Test Steps
1. **Launch Neovim** with the migrated configuration
2. **Test Navigation Keymaps**:
   - `<C-d>` and `<C-u>` for half page navigation
   - `<Esc>` to clear search highlights
   - `gd` to go to definition (in a file with LSP)
3. **Test File Operations**:
   - `<leader>ff` to open file picker
   - `<leader>fe` to open file explorer
   - `<C-s>` to save file
4. **Test Buffer Operations**:
   - `<S-h>` and `<S-l>` for buffer navigation
   - `<leader>bd` to delete buffer
   - `<leader>bb` to switch to other buffer
5. **Test Window Operations**:
   - `<leader>-` to split window below
   - `<leader>|` to split window right
   - `<leader>wd` to delete window
6. **Test Search Operations**:
   - `s` to trigger Flash search
   - `<leader>sg` to open grug-far search
   - `<leader>/` to live grep
7. **Test LSP Operations**:
   - `<leader>ca` for code actions
   - `grr` for LSP references
   - `]d` and `[d` for diagnostic navigation
8. **Test Git Operations**:
   - `<leader>gs` to stage hunk
   - `<leader>gp` to preview hunk
   - `<leader>gb` to blame line
9. **Test Plugin-Specific Operations**:
   - `<leader>tt` to run tests (neotest)
   - `<leader>o` for overseer commands
   - `<leader>D` for DBUI toggle
10. **Test Yanky Operations**:
    - `y` and `p` for yank and put
    - `<leader>p` to open yank history
    - `]p` for put indented after

## Expected Results
- All navigation keymaps work correctly
- File operations open appropriate interfaces
- Buffer navigation works smoothly
- Window splitting functions properly
- Search operations trigger correct plugins
- LSP operations provide expected functionality
- Git operations execute without errors
- Plugin-specific commands work as expected
- Yanky operations function correctly

## Validation Method
1. **Manual Verification**: Use each keymap and observe expected behavior
2. **Keymap Listing**: Run `:verbose map <key>` to verify keymap is defined and functional
3. **Error Checking**: Monitor for any error messages when using keymaps
4. **Plugin Loading**: Verify plugins load when their keymaps are used
5. **Functionality Test**: Perform actual operations (e.g., create a file and save it with `<C-s>`)

## Success Criteria
- ✅ All tested keymaps execute without errors
- ✅ Each keymap produces expected functionality
- ✅ No error messages appear when using keymaps
- ✅ Plugins load appropriately when their keymaps are triggered
- ✅ User workflow remains unchanged from pre-migration state

---
*Contract test completed: 2025-10-05*