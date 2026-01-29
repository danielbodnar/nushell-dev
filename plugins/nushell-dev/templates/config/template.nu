# {{NAME}} configuration snippet
#
# Add this to your config.nu or source it separately
#
# Usage:
#   source {{NAME}}-config.nu
#   # Or add contents to ~/.config/nushell/config.nu
#
# Author: {{AUTHOR}}
# Created: {{DATE}}

# ============================================================================
# Environment Variables
# ============================================================================

# {{NAME}} home directory
$env.{{NAME_UPPER}}_HOME = ($env.HOME | path join ".{{NAME}}")

# {{NAME}} configuration
$env.{{NAME_UPPER}}_CONFIG = {
    # Enable debug logging
    debug: false

    # Default output format
    output_format: "table"

    # Maximum items to process
    max_items: 1000

    # Timeout for operations (duration)
    timeout: 30sec

    # Custom paths
    data_dir: ($env.{{NAME_UPPER}}_HOME | path join "data")
    cache_dir: ($env.{{NAME_UPPER}}_HOME | path join "cache")
}

# ============================================================================
# Aliases
# ============================================================================

# Short alias for main command
alias {{NAME_SHORT}} = {{NAME}}

# Common operations
# alias {{NAME_SHORT}}l = {{NAME}} list
# alias {{NAME_SHORT}}s = {{NAME}} status

# ============================================================================
# Completions
# ============================================================================

# Custom completions for {{NAME}} commands
def "nu-complete {{NAME}} formats" [] {
    ["json", "csv", "table", "yaml", "nuon"]
}

# ============================================================================
# Hooks (Optional)
# ============================================================================

# Pre-prompt hook example
# $env.config.hooks.pre_prompt = ($env.config.hooks.pre_prompt | append {||
#     # Custom logic before each prompt
# })

# ============================================================================
# Initialization
# ============================================================================

# Create directories if they don't exist
if not ($env.{{NAME_UPPER}}_HOME | path exists) {
    mkdir $env.{{NAME_UPPER}}_HOME
    mkdir ($env.{{NAME_UPPER}}_CONFIG.data_dir)
    mkdir ($env.{{NAME_UPPER}}_CONFIG.cache_dir)
}

# Load module (if installed)
# use {{NAME}}
