# {{NAME}} - {{DESCRIPTION}}
#
# {{DETAILED_DESCRIPTION}}
#
# Examples:
#   {{NAME}} input.json
#   {{NAME}} --format csv data.txt
#
# Author: {{AUTHOR}}
# Created: {{DATE}}

# {{DESCRIPTION}}
#
# Processes input data according to the specified format.
# Returns the processed result.
#
# Examples:
#   {{NAME}} "input"
#   {{NAME}} "input" --format json
export def {{NAME}} [
    input: string          # Input data to process
    --format: string       # Output format (json, csv, text)
    --verbose (-v)         # Enable verbose output
] -> any {
    if $verbose {
        print $"Processing: ($input)"
    }

    # TODO: Implement your command logic here
    let result = process-input $input $format

    $result
}

# Internal helper function
def process-input [input: string, format: string] -> any {
    match $format {
        "json" => { {input: $input, format: "json"} }
        "csv" => { [[$"input"]; [$input]] }
        _ => { $input }
    }
}
