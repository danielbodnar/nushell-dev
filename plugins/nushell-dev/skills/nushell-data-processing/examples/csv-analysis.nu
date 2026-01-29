#!/usr/bin/env nu
# csv-analysis.nu - Analyze CSV data using Polars
#
# Demonstrates common CSV analysis patterns:
# - Loading and exploring data
# - Cleaning and transforming
# - Aggregations and summaries
# - Exporting results
#
# Usage:
#   nu csv-analysis.nu --input data.csv
#   nu csv-analysis.nu --input data.csv --output report.json

def main [
    --input (-i): path     # Input CSV file
    --output (-o): path    # Output file for report
    --sample: int = 5      # Number of sample rows to show
] {
    if $input == null {
        print "Usage: nu csv-analysis.nu --input <file.csv>"
        exit 1
    }

    print $"Analyzing: ($input)"
    print "=" * 50

    # Load data
    let df = polars open $input

    # Basic info
    print "\n📊 Dataset Overview"
    print $"  Rows: (($df | polars shape).0)"
    print $"  Columns: (($df | polars shape).1)"

    # Column info
    print "\n📋 Column Types"
    $df | polars schema | transpose name dtype | print

    # Sample data
    print $"\n🔍 Sample Data (first ($sample) rows)"
    $df | polars first $sample | polars into-nu | print

    # Numeric summary
    print "\n📈 Numeric Summary"
    $df | polars describe | polars into-nu | print

    # Missing values
    print "\n❓ Missing Values"
    let null_counts = $df | polars null-count | polars into-nu | transpose column nulls
    $null_counts | where nulls > 0 | print

    # Generate report
    let report = {
        file: $input
        rows: ($df | polars shape).0
        columns: ($df | polars shape).1
        schema: ($df | polars schema | transpose name dtype | polars into-nu)
        null_counts: $null_counts
        generated_at: (date now | format date "%Y-%m-%d %H:%M:%S")
    }

    # Save if output specified
    if $output != null {
        $report | to json --indent 2 | save --force $output
        print $"\n✅ Report saved to: ($output)"
    }

    $report
}
