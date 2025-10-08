# Contract Test: Startup Performance

**Requirement**: FR-005 - System MUST improve startup performance by reducing immediate plugin loading
**Description**: Verify that startup time improves after lazy loading implementation

## Preconditions
- Baseline startup time measurement from before migration
- Migrated configuration with lazy-loaded keymaps
- Neovim 0.9+ with startup time measurement capability
- Consistent testing environment (same machine, no background changes)

## Test Steps
1. **Measure Baseline Startup Time** (if not already done):
   ```bash
   nvim --startuptime baseline-startup.log +qa
   ```
   Extract total startup time from the last line of the log

2. **Measure Migrated Startup Time**:
   ```bash
   nvim --startuptime migrated-startup.log +qa
   ```
   Extract total startup time from the last line of the log

3. **Compare Startup Times**:
   ```bash
   echo "Baseline: $(tail -1 baseline-startup.log)"
   echo "Migrated: $(tail -1 migrated-startup.log)"
   ```

4. **Measure Memory Usage**:
   ```bash
   # Create a script to measure memory usage
   cat > measure_memory.lua << 'EOF'
   local function measure_memory()
     local before = collectgarbage("count")
     -- Force garbage collection
     collectgarbage("collect")
     local after = collectgarbage("count")
     print(string.format("Memory usage: %.2f MB", after))
     return after
   end
   
   measure_memory()
   EOF
   
   nvim -l measure_memory.lua
   ```

5. **Profile Plugin Loading**:
   ```lua
   :Lazy profile
   ```
   Check which plugins load at startup vs on-demand

## Expected Results
- Migrated startup time should be less than baseline startup time
- Memory usage should be reduced
- Fewer plugins should load at startup
- Plugin loading should be deferred until keymaps are used

## Validation Method
1. **Quantitative Comparison**:
   - Calculate percentage improvement: `(baseline - migrated) / baseline * 100`
   - Target: Minimum 10% startup time improvement
   - Target: Minimum 5% memory usage reduction

2. **Plugin Loading Analysis**:
   - Count plugins loaded at startup in baseline vs migrated
   - Verify that plugins with keymaps now load on-demand
   - Check that essential plugins still load appropriately

3. **Lazy Loading Verification**:
   - Use `:Lazy` to check plugin status
   - Verify plugins show as "not loaded" until their keymaps are used
   - Test that plugins load immediately when their keymaps are triggered

## Success Criteria
- ✅ Startup time improvement of at least 10%
- ✅ Memory usage reduction of at least 5%
- ✅ Plugins with keymaps load on-demand instead of at startup
- ✅ Essential functionality remains available immediately
- ✅ No negative impact on user experience

## Performance Targets
- **Startup Time**: < 100ms (constitutional requirement)
- **Memory Usage**: < 50MB baseline (target 10% reduction)
- **Plugin Loading**: Minimum 50% reduction in immediate plugin loading

---
*Contract test completed: 2025-10-05*