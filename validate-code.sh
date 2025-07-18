#!/bin/bash
set -ex

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
        add_to_report "ℹ️ No HTML files found"
        return 0
    fi

    for file in $html_files; do
        echo "Validating HTML: $file"

        # Validate HTML structure
        if command -v htmlhint >/dev/null 2>&1; then
            if htmlhint "$file"; then
                add_to_report "✅ HTML structure valid: $file"
            else
                add_to_report "❌ HTML structure issues: $file"
                VALIDATION_PASSED=false
            fi
        else
            add_to_report "⚠️ HTML validation skipped (htmlhint missing)"
        fi

        # Extract and validate inline CSS
        echo "Validating inline CSS in: $file"
        awk '/<style>/,/<\/style>/ {if (!/<style>/ && !/<\/style>/) print}' "$file" > inline_css.tmp
        if [ -s inline_css.tmp ]; then
            if command -v csslint >/dev/null 2>&1; then
                if csslint --errors=errors inline_css.tmp > csslint_errors.txt 2>&1; then
                    add_to_report "✅ Inline CSS valid: $file"
                else
                    add_to_report "❌ Inline CSS errors: $file"
                    add_to_report "   $(grep 'Error' csslint_errors.txt | head -n 3)"
                    VALIDATION_PASSED=false
                fi
                rm -f csslint_errors.txt
            else
                add_to_report "⚠️ CSS validation skipped (csslint missing)"
            fi
        fi
        rm -f inline_css.tmp

        # Extract and validate inline JavaScript
        echo "Validating inline JavaScript in: $file"
        awk '/<script>/,/<\/script>/ {if (!/<script>/ && !/<\/script>/) print}' "$file" > inline_js.tmp
        if [ -s inline_js.tmp ]; then
            if command -v eslint >/dev/null 2>&1; then
                if eslint --no-eslintrc --parser-options=ecmaVersion:2020 -f compact inline_js.tmp > eslint_errors.txt 2>&1; then
                    add_to_report "✅ Inline JavaScript valid: $file"
                else
                    add_to_report "❌ Inline JavaScript errors: $file"
                    add_to_report "   $(grep 'Error' eslint_errors.txt | head -n 3)"
                    VALIDATION_PASSED=false
                fi
                rm -f eslint_errors.txt
            else
                add_to_report "⚠️ JavaScript validation skipped (eslint missing)"
            fi
        fi
        rm -f inline_js.tmp
    done
}

# Run validations
validate_html

# Generate validation report
echo "=== CODE VALIDATION REPORT ===" > validation_report.txt
echo "Generated: $(date)" >> validation_report.txt
echo "Build Number: ${BUILD_NUMBER:-'N/A'}" >> validation_report.txt
echo "Git Commit: $(git rev-parse HEAD 2>/dev/null || echo 'N/A')" >> validation_report.txt
echo "" >> validation_report.txt
echo -e "$VALIDATION_REPORT" >> validation_report.txt
echo "=============================" >> validation_report.txt

# Print final result
if [ "$VALIDATION_PASSED" = true ]; then
    echo "🎉 VALIDATION PASSED! Code is production ready."
    echo "VALIDATION_STATUS=SUCCESS" > validation_status.txt
    exit 0
else
    echo "❌ VALIDATION FAILED! Please fix the reported issues."
    echo "VALIDATION_STATUS=FAILED" > validation_status.txt
    exit 1
fi
