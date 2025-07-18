#!/bin/bash
set -e

VALIDATION_PASSED=true
VALIDATION_REPORT=""

add_to_report() {
    VALIDATION_REPORT="$VALIDATION_REPORT\n$1"
}

validate_html() {
    echo "Validating HTML files..."
    for file in *.html; do
        echo "Validating: $file"
        
        # HTMLHint validation
        if htmlhint "$file"; then
            add_to_report "✅ HTML validation passed: $file"
        else
            add_to_report "❌ HTML validation failed: $file"
            VALIDATION_PASSED=false
        fi
        
        # Tidy validation
        if tidy -q -e "$file"; then
            add_to_report "✅ HTML structure valid: $file"
        else
            add_to_report "⚠️ HTML structure warnings: $file"
        fi
    done
}

validate_css() {
    echo "Validating CSS..."
    for file in *.css; do
        echo "Validating: $file"
        if csslint "$file"; then
            add_to_report "✅ CSS validation passed: $file"
        else
            add_to_report "❌ CSS validation failed: $file"
            VALIDATION_PASSED=false
        fi
    done
}

validate_js() {
    echo "Validating JavaScript..."
    for file in *.js; do
        echo "Validating: $file"
        if jshint "$file"; then
            add_to_report "✅ JavaScript validation passed: $file"
        else
            add_to_report "❌ JavaScript validation failed: $file"
            VALIDATION_PASSED=false
        fi
    done
}

# Run validations
validate_html
validate_css
validate_js

# Generate report
echo -e "=== VALIDATION REPORT ===\n$VALIDATION_REPORT" > validation_report.txt

if $VALIDATION_PASSED; then
    echo "VALIDATION_STATUS=SUCCESS" > validation_status.txt
    exit 0
else
    echo "VALIDATION_STATUS=FAILED" > validation_status.txt
    exit 1
fi
