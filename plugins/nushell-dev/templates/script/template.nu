#!/usr/bin/env nu
# {{NAME}}.nu - {{DESCRIPTION}}
#
# {{DETAILED_DESCRIPTION}}
#
# Usage:
#   nu {{NAME}}.nu [options]
#
# Examples:
#   nu {{NAME}}.nu
#   nu {{NAME}}.nu --verbose
#
# Author: {{AUTHOR}}
# Created: {{DATE}}

# Configuration
const VERSION = "1.0.0"

# Main entry point
def main [
    --verbose (-v)    # Enable verbose output
    --dry-run (-n)    # Show what would be done without doing it
] {
    if $verbose {
        print $"Starting {{NAME}} v($VERSION)"
    }

    # Main logic here
    let result = do-work --dry-run=$dry_run

    if $verbose {
        print "Completed successfully"
    }

    $result
}

# Main work function
def do-work [--dry-run: bool] {
    if $dry_run {
        print "Dry run mode - no changes will be made"
        return null
    }

    # TODO: Implement your logic here
    "Hello from {{NAME}}!"
}
