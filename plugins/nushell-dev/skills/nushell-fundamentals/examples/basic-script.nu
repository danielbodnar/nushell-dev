#!/usr/bin/env nu
# basic-script.nu - Template for standalone Nushell scripts
#
# A well-structured Nushell script with configuration, logging, and error handling.
#
# Usage:
#   nu basic-script.nu [options]
#
# Examples:
#   nu basic-script.nu
#   nu basic-script.nu --verbose --dry-run

# Configuration
const VERSION = "1.0.0"
const SCRIPT_NAME = "basic-script"

# Parse command line and run main
def main [
    --verbose (-v)    # Enable verbose output
    --dry-run (-n)    # Show what would be done without doing it
    --config: path    # Path to config file
] {
    # Initialize logging
    let log_level = if $verbose { "debug" } else { "info" }

    # Load configuration
    let config = load-config $config

    # Log startup
    log info $"Starting ($SCRIPT_NAME) v($VERSION)"
    if $verbose {
        log debug $"Config: ($config | to nuon)"
    }

    # Main logic
    try {
        if $dry_run {
            log info "Dry run mode - no changes will be made"
        }

        do-work $config --dry-run=$dry_run

        log info "Completed successfully"
    } catch { |err|
        log error $"Failed: ($err.msg)"
        exit 1
    }
}

# Load configuration from file or defaults
def load-config [config_path?: path] -> record {
    let default_config = {
        output_dir: "./output"
        max_items: 100
        timeout: 30sec
    }

    if $config_path != null and ($config_path | path exists) {
        let user_config = open $config_path
        $default_config | merge $user_config
    } else {
        $default_config
    }
}

# Main work function
def do-work [config: record, --dry-run: bool] {
    # Example: Process files
    let files = ls | where type == "file" | first $config.max_items

    log info $"Processing ($files | length) files"

    $files | each { |file|
        if $dry_run {
            log debug $"Would process: ($file.name)"
        } else {
            process-file $file
        }
    }
}

# Process a single file
def process-file [file: record] {
    log debug $"Processing: ($file.name)"
    # Add your processing logic here
}

# Simple logging functions
def "log info" [msg: string] {
    print $"[INFO] ($msg)"
}

def "log debug" [msg: string] {
    if $env.DEBUG? != null {
        print $"[DEBUG] ($msg)"
    }
}

def "log error" [msg: string] {
    print -e $"[ERROR] ($msg)"
}
