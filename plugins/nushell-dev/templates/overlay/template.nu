# {{NAME}} overlay - {{DESCRIPTION}}
#
# {{DETAILED_DESCRIPTION}}
#
# Usage:
#   overlay use {{NAME}}.nu
#   overlay hide {{NAME}}
#
# Author: {{AUTHOR}}
# Created: {{DATE}}

# Environment modifications for this overlay
export-env {
    # Set environment variables
    $env.{{NAME_UPPER}}_ENABLED = true
    $env.{{NAME_UPPER}}_VERSION = "1.0.0"

    # Add to PATH (if needed)
    # $env.PATH = ($env.PATH | prepend "/custom/bin")

    # Custom configuration
    $env.{{NAME_UPPER}}_CONFIG = {
        debug: false
        log_level: "info"
        output_dir: "."
    }
}

# Commands available in this overlay

# Initialize the overlay environment
#
# Call this after activating the overlay to set up resources.
export def "{{NAME}} init" [] {
    print $"{{NAME}} overlay initialized"
    print $"Config: ($env.{{NAME_UPPER}}_CONFIG | to nuon)"
}

# Configure overlay settings
#
# Examples:
#   {{NAME}} config --debug
#   {{NAME}} config --log-level debug
export def "{{NAME}} config" [
    --debug          # Enable debug mode
    --log-level: string  # Set log level (debug, info, warn, error)
] {
    if $debug {
        $env.{{NAME_UPPER}}_CONFIG = ($env.{{NAME_UPPER}}_CONFIG | upsert debug true)
    }

    if $log_level != null {
        $env.{{NAME_UPPER}}_CONFIG = ($env.{{NAME_UPPER}}_CONFIG | upsert log_level $log_level)
    }

    $env.{{NAME_UPPER}}_CONFIG
}

# Show overlay status
export def "{{NAME}} status" [] {
    {
        enabled: $env.{{NAME_UPPER}}_ENABLED
        version: $env.{{NAME_UPPER}}_VERSION
        config: $env.{{NAME_UPPER}}_CONFIG
    }
}
