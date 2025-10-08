# Contract Test: Keymap Organization

**Requirement**: FR-001 - System MUST relocate custom keymap definitions from centralized location to their respective plugin configuration files
**Description**: Verify that keymaps are properly organized in their respective plugin files

## Preconditions
- Migration process is complete
- Keymaps have been moved from config/keymaps.lua to plugin files
- Plugin files have been updated with keymaps
- Original keymap file has been cleaned up

## Test Steps
1. **Verify Central Keymap File Cleanup**:
   - Check `config/keymaps.lua` for remaining keymaps
   - Verify only core/universal keymaps remain
   - Ensure no plugin-specific keymaps remain

2. **Check Plugin File Organization**:
   - Verify `lua/plugins/mini/files.lua` contains file explorer keymaps
   - Verify `lua/plugins/lsp.lua` contains LSP-related keymaps
   - Verify `lua/plugins/general.lua` contains general utility keymaps
   - Verify `lua/plugins/git.lua` contains git-related keymaps

3. **Validate Keymap Distribution**:
   ```bash
   # Count keymaps in each plugin file
   grep -c "keymap\|keys" /path/to/plugin/files
   ```
   Ensure keymaps are distributed appropriately

4. **Check Plugin Configuration Structure**:
   - Verify each plugin file has proper `keys = {}` configuration
   - Check that keymaps use correct lazy.nvim syntax
   - Ensure descriptions are present for all keymaps

5. **Verify Loading Triggers**:
   - Check that plugins use appropriate `keys` configuration
   - Verify lazy loading is properly configured
   - Ensure no immediate loading occurs

6. **Validate Keymap Syntax**:
   - Check that all keymaps follow the same pattern
   - Verify mode specifications are correct
   - Ensure descriptions are consistent

7. **Test File Completeness**:
   - Verify all plugin files that should have keymaps do have them
   - Check that no plugin files are missing expected keymaps
   - Ensure all original keymaps are accounted for

## Expected Results
- Central keymap file contains only essential/universal keymaps
- Plugin-specific keymaps are in their respective plugin files
- All keymaps use proper lazy.nvim `keys = {}` syntax
- Keymaps are organized logically by plugin functionality
- No duplicate keymaps exist across files
- Loading triggers are properly configured

## Validation Method
1. **File Content Analysis**:
   - Use `grep` to find keymap definitions
   - Check file sizes and content organization
   - Verify syntax correctness

2. **Structure Validation**:
   ```lua
   -- Sample validation script
   local function validate_plugin_file(file)
     local content = io.open(file, "r"):read("*all")
     -- Check for proper keys configuration
     return content:match('keys%s*=%s*{') ~= nil
   end
   ```

3. **Cross-Reference Verification**:
   - Compare original keymaps with migrated ones
   - Ensure all functionality is preserved
   - Check for missing or duplicate keymaps

## Success Criteria
- ✅ Central keymap file is cleaned up (only essential keymaps remain)
- ✅ All plugin-specific keymaps are moved to appropriate plugin files
- ✅ Proper lazy.nvim `keys = {}` syntax is used
- ✅ Keymaps are organized logically by functionality
- ✅ No duplicate or missing keymaps
- ✅ Loading triggers are correctly configured

## Organization Structure
```
lua/plugins/
├── mini/files.lua       # File explorer keymaps
├── lsp.lua             # LSP-related keymaps  
├── general.lua         # General utilities (flash, etc.)
├── git.lua             # Git operations keymaps
├── neotest.lua         # Testing framework keymaps
└── ...                 # Other plugin files with their keymaps

config/keymaps.lua      # Only essential/universal keymaps
```

---
*Contract test completed: 2025-10-05*