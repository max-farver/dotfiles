# Data Model: Keymap Reorganization

## Key Entities

### Keymap Configuration
**Purpose**: Represents a keybinding definition and its association with a specific plugin
**Attributes**:
- **mode**: Vim mode(s) for the keymap (n, i, v, x, o, etc.)
- **lhs**: Left-hand side (the key combination pressed)
- **rhs**: Right-hand side (the action performed)
- **desc**: Description of the keymap's functionality
- **plugin**: Associated plugin that provides the functionality
- **lazy_loading**: Loading strategy (event, command, file-type)

### Plugin Configuration
**Purpose**: Represents a plugin configuration with its keymaps and loading strategy
**Attributes**:
- **name**: Plugin identifier
- **loading_strategy**: How the plugin should be loaded (event, command, ft, keys)
- **keymaps**: List of associated keymap configurations
- **dependencies**: Other plugins this one depends on

### Loading Strategy
**Purpose**: Defines when and how plugins should be loaded
**Attributes**:
- **type**: Event, command, file-type, or key-based loading
- **trigger**: Specific event/command/file-type that triggers loading
- **priority**: Loading order priority

## Entity Relationships

### Keymap to Plugin Configuration
- **Relationship**: Many-to-One
- **Description**: Multiple keymaps can belong to one plugin configuration
- **Constraint**: A keymap must be associated with exactly one plugin configuration

### Plugin Configuration to Loading Strategy
- **Relationship**: One-to-One
- **Description**: Each plugin configuration has exactly one loading strategy
- **Constraint**: Loading strategy must be appropriate for the plugin's functionality

## Data Flow

### Current State Analysis
1. **Centralized Keymaps**: All keymaps defined in `config/keymaps.lua`
2. **Immediate Loading**: All plugins with keymaps load immediately
3. **Performance Impact**: Startup time degraded by unnecessary plugin loading

### Target State Design
1. **Distributed Keymaps**: Keymaps moved to respective plugin files
2. **Lazy Loading**: Plugins load only when needed
3. **Performance Optimization**: Reduced startup time and memory usage

## Validation Rules

### Keymap Validation
- **Unique Key Combination**: No duplicate keymaps in same mode
- **Plugin Availability**: Plugin must exist before keymap association
- **Loading Strategy Compatibility**: Loading strategy must match plugin usage patterns

### Plugin Configuration Validation
- **Dependency Resolution**: All plugin dependencies must be satisfied
- **Loading Strategy Appropriateness**: Strategy must match plugin functionality
- **Keymap Completeness**: All necessary keymaps must be present

## State Transitions

### Migration Process
1. **Analysis Phase**: Identify keymaps and their plugin associations
2. **Migration Phase**: Move keymaps to plugin configuration files
3. **Validation Phase**: Test that all keymaps remain functional
4. **Optimization Phase**: Fine-tune loading strategies for performance

### Loading State Machine
```
[Not Loaded] → [Loading Trigger] → [Loaded] → [Active]
    ↑                                          ↓
    └─────────── [Unload] ←────────────────────┘
```

## Performance Considerations

### Startup Metrics
- **Keymaps to Migrate**: ~95 keymaps across multiple plugins
- **Expected Impact**: Reduction in startup time by lazy loading non-essential plugins
- **Memory Usage**: Reduced memory footprint by loading plugins on demand

### Loading Optimization
- **Event-based Loading**: Use `VeryLazy` for non-essential plugins
- **Command-based Loading**: Load plugins only when their commands are used
- **File-type Loading**: Load language-specific plugins only for relevant file types

---
*Data model completed: 2025-10-05*