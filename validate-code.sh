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
        add_to_report "⚠️ No HTML files found"
        return 0
    fi

    for file in $html_files; do
        echo "Validating HTML: $file"

        # Validate with tidy
        if command -v tidy >/dev/null 2>&1; then
            if ! tidy -q -e "$file" 2>tidy_errors.txt; then
                echo "❌ HTML validation failed for: $file"
                add_to_report "❌ HTML validation failed for: $file"
                cat tidy_errors.txt | sed 's/^/    /'
                add_to_report "    $(cat tidy_errors.txt | tr '\n' ' ')"
                VALIDATION_PASSED=false
            else
                echo "✅ HTML validation passed for: $file"
                add_to_report "✅ HTML validation passed for: $file"
            fi
            rm -f tidy_errors.txt
        else
            echo "⚠️  tidy not available, skipping HTML validation"
            add_to_report "⚠️ HTML validation skipped (tidy missing)"
        fi

        # Extract and validate inline JavaScript
        echo "Validating inline JavaScript in: $file"
        awk '/<script>/,/<\/script>/ {if (!/<script>/ && !/<\/script>/) print}' "$file" > inline_js.tmp
        if [ -s inline_js.tmp ]; then
            if command -v eslint >/dev/null 2>&1; then
                if ! eslint --no-eslintrc --parser-options=ecmaVersion:2020 inline_js.tmp > eslint_errors.txt 2>&1; then
                    echo "❌ Inline JavaScript validation failed in: $file"
                    add_to_report "❌ Inline JavaScript validation failed in: $file"
                    cat eslint_errors.txt | sed 's/^/    /'
                    add_to_report "    $(cat eslint_errors.txt | tr '\n' ' ')"
                    VALIDATION_PASSED=false
                fi
                rm -f eslint_errors.txt
            else
                echo "⚠️  eslint not available, skipping inline JS validation"
                add_to_report "⚠️ Inline JS validation skipped (eslint missing)"
            fi
        fi
        rm -f inline_js.tmp

        # Extract and validate inline CSS
        echo "Validating inline CSS in: $file"
        awk '/<style>/,/<\/style>/ {if (!/<style>/ && !/<\/style>/) print}' "$file" > inline_css.tmp
        if [ -s inline_css.tmp ]; then
            if command -v csslint >/dev/null 2>&1; then
                if ! csslint --format=compact inline_css.tmp > csslint_errors.txt 2>&1; then
                    echo "❌ Inline CSS validation failed in: $file"
                    add_to_report "❌ Inline CSS validation failed in: $file"
                    cat csslint_errors.txt | sed 's/^/    /'
                    add_to_report "    $(cat csslint_errors.txt | tr '\n' ' ')"
                    VALIDATION_PASSED=false
                fi
                rm -f csslint_errors.txt
            else
                echo "⚠️  csslint not available, skipping inline CSS validation"
                add_to_report "⚠️ Inline CSS validation skipped (csslint missing)"
            fi
        fi
        rm -f inline_css.tmp
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
            if ! csslint --format=compact "$file" > csslint_errors.txt 2>&1; then
                echo "❌ CSS validation failed for: $file"
                add_to_report "❌ CSS validation failed for: $file"
                cat csslint_errors.txt | sed 's/^/    /'
                add_to_report "    $(cat csslint_errors.txt | tr '\n' ' ')"
                VALIDATION_PASSED=false
            else
                echo "✅ CSS validation passed for: $file"
                add_to_report "✅ CSS validation passed for: $file"
            fi
            rm -f csslint_errors.txt
        else
            echo "⚠️  csslint not available"
            add_to_report "⚠️ CSS validation skipped (csslint missing)"
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

        if command -v eslint >/dev/null 2>&1; then
            if ! eslint --no-eslintrc --parser-options=ecmaVersion:2020 "$file" > eslint_errors.txt 2>&1; then
                echo "❌ JavaScript validation failed for: $file"
                add_to_report "❌ JavaScript validation failed for: $file"
                cat eslint_errors.txt | sed 's/^/    /'
                add_to_report "    $(cat eslint_errors.txt | tr '\n' ' ')"
                VALIDATION_PASSED=false
            else
                echo "✅ JavaScript validation passed for: $file"
                add_to_report "✅ JavaScript validation passed for: $file"
            fi
            rm -f eslint_errors.txt
        else
            echo "⚠️  eslint not available"
            add_to_report "⚠️ JavaScript validation skipped (eslint missing)"
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
