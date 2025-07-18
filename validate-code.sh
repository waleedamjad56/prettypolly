#!/bin/bash
set -e

VALIDATION_PASSED=true
VALIDATION_REPORT=""

add_to_report() {
    VALIDATION_REPORT="$VALIDATION_REPORT\n$1"
}

validate_html() {
    echo "Validating HTML files..."
    local html_files=$(find . -name "*.html" -not -path "./node_modules/*")

    if [ -z "$html_files" ]; then
        echo "No HTML files found to validate."
        add_to_report "⚠️ No HTML files found"
        return 0
    fi

    for file in $html_files; do
        echo "Validating HTML: $file"

        if command -v htmlhint >/dev/null 2>&1; then
            if htmlhint "$file"; then
                add_to_report "✅ HTML validation passed: $file"
            else
                add_to_report "❌ HTML validation failed: $file"
                VALIDATION_PASSED=false
            fi
        else
            echo "⚠️  htmlhint not available"
        fi

        if command -v tidy >/dev/null 2>&1; then
            if ! tidy -q -e "$file" 2>/dev/null; then
                add_to_report "⚠️  HTML structure warnings: $file"
            fi
        fi
    done
}

validate_css() {
    echo "Looking for CSS files..."
    local css_files=$(find . -name "*.css" -not -path "./node_modules/*")

    if [ -z "$css_files" ]; then
        echo "No CSS files found to validate."
        add_to_report "⚠️ No CSS files found"
        return 0
    fi

    for file in $css_files; do
        echo "Validating CSS: $file"

        if command -v csslint >/dev/null 2>&1; then
            if csslint "$file"; then
                add_to_report "✅ CSS validation passed: $file"
            else
                add_to_report "❌ CSS validation failed: $file"
                VALIDATION_PASSED=false
            fi
        else
            echo "⚠️  csslint not available"
        fi
    done
}

validate_js() {
    echo "Looking for JavaScript files..."
    local js_files=$(find . -name "*.js" -not -path "./node_modules/*")

    if [ -z "$js_files" ]; then
        echo "No JavaScript files found to validate."
        add_to_report "⚠️ No JavaScript files found"
        return 0
    fi

    for file in $js_files; do
        echo "Validating JS: $file"

        if command -v jshint >/dev/null 2>&1; then
            if jshint "$file"; then
                add_to_report "✅ JavaScript validation passed: $file"
            else
                add_to_report "❌ JavaScript validation failed: $file"
                VALIDATION_PASSED=false
            fi
        else
            echo "⚠️  jshint not available"
        fi
    done
}

# Run validations
validate_html
validate_css
validate_js

# Generate validation report
echo "=== VALIDATION REPORT ===" > validation_report.txt
echo "Generated: $(date)" >> validation_report.txt
echo "Build Number: ${BUILD_NUMBER:-'N/A'}" >> validation_report.txt
echo "Git Commit: $(git rev-parse HEAD 2>/dev/null || echo 'N/A')" >> validation_report.txt
echo "" >> validation_report.txt
echo -e "$VALIDATION_REPORT" >> validation_report.txt
echo "=========================" >> validation_report.txt

# Print final result
if [ "$VALIDATION_PASSED" = true ]; then
    echo "🎉 ALL VALIDATIONS PASSED! Code is ready for deployment."
    echo "VALIDATION_STATUS=SUCCESS" > validation_status.txt
    exit 0
else
    echo "❌ VALIDATION FAILED! Please fix the issues before deployment."
    echo "VALIDATION_STATUS=FAILED" > validation_status.txt
    exit 1
fi
