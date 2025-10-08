#!/bin/bash
# Performance measurement script for Neovim startup time

# Configuration
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BASE_DIR="/home/mfarver/.config/nvim/specs/001-move-custom-keymap"
RESULTS_DIR="$BASE_DIR/results"

# Create results directory if it doesn't exist
mkdir -p "$RESULTS_DIR"

# Function to measure startup time
measure_startup() {
    local label="$1"
    local output_file="$RESULTS_DIR/${label}_${TIMESTAMP}.log"
    
    echo "Measuring startup time for: $label"
    nvim --startuptime "$output_file" +qa
    
    if [ -f "$output_file" ]; then
        local total_time=$(tail -1 "$output_file" | awk '{print $1}')
        echo "Startup time for $label: ${total_time}ms"
        echo "${label}: ${total_time}ms" >> "$RESULTS_DIR/summary.txt"
        return 0
    else
        echo "Error: Failed to create startup log for $label"
        return 1
    fi
}

# Function to measure memory usage
measure_memory() {
    local label="$1"
    local script_file="/tmp/memory_measure_$TIMESTAMP.lua"
    
    cat > "$script_file" << 'EOF'
local function measure_memory()
    -- Force garbage collection to get clean baseline
    collectgarbage("collect")
    collectgarbage("collect")
    
    local before = collectgarbage("count")
    
    -- Wait a bit for any background processes
    vim.loop.sleep(100)
    
    local after = collectgarbage("count")
    local peak = collectgarbage("count")
    
    print(string.format("Memory usage: %.2f MB (before: %.2f, peak: %.2f)", after, before, peak))
    return after
end

measure_memory()
EOF

    echo "Measuring memory usage for: $label"
    local memory_output=$(nvim -l "$script_file" 2>/dev/null)
    echo "Memory usage for $label: $memory_output"
    echo "${label}: $memory_output" >> "$RESULTS_DIR/memory_summary.txt"
    
    rm -f "$script_file"
}

# Function to profile plugin loading
profile_plugins() {
    local label="$1"
    local profile_file="$RESULTS_DIR/${label}_profile_$TIMESTAMP.log"
    
    echo "Profiling plugin loading for: $label"
    
    # Create a script to profile plugins
    local profile_script="/tmp/profile_$TIMESTAMP.lua"
    cat > "$profile_script" << 'EOF'
-- Profile plugin loading
local lazy = require('lazy')
local stats = require('lazy.stats')

-- Print loading statistics
print("=== Plugin Loading Profile ===")
print("Total plugins: " .. stats.count())
print("Loaded plugins: " .. stats.loaded())
print("Load time: " .. (stats.startuptime() or "N/A"))

-- Print individual plugin load times
if lazy.stats then
    print("\n=== Individual Plugin Load Times ===")
    for _, plugin in pairs(lazy.plugins()) do
        if plugin._.loaded then
            local load_time = plugin._.loadtime or 0
            if load_time > 0 then
                print(string.format("%s: %.2fms", plugin.name, load_time))
            end
        end
    end
end
EOF

    nvim --headless -l "$profile_script" > "$profile_file" 2>/dev/null
    
    if [ -f "$profile_file" ]; then
        echo "Plugin profile saved to: $profile_file"
        cat "$profile_file"
    else
        echo "Error: Failed to create plugin profile for $label"
    fi
    
    rm -f "$profile_script"
}

# Main execution
case "${1:-all}" in
    "startup")
        measure_startup "current"
        ;;
    "memory")
        measure_memory "current"
        ;;
    "profile")
        profile_plugins "current"
        ;;
    "all")
        echo "=== Running Full Performance Analysis ==="
        measure_startup "baseline"
        measure_memory "baseline"
        profile_plugins "baseline"
        echo "=== Analysis Complete ==="
        echo "Results saved to: $RESULTS_DIR"
        ;;
    *)
        echo "Usage: $0 {startup|memory|profile|all}"
        exit 1
        ;;
esac