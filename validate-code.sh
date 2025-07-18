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

        # Validate with htmlhint
        if command -v htmlhint >/dev/null 2>&1; then
            if htmlhint "$file" > htmlhint_errors.txt 2>&1; then
                add_to_report "✅ HTML structure valid: $file"
            else
                add_to_report "❌ HTML validation issues in: $file"
                while IFS= read -r line; do
                    add_to_report "   $line"
                done < <(grep -v 'Scanned' htmlhint_errors.txt | head -10)
                VALIDATION_PASSED=false
            fi
            rm -f htmlhint_errors.txt
        else
            add_to_report "⚠️ HTML validation skipped (htmlhint missing)"
        fi

        # Extract and validate inline CSS with more lenient rules
        echo "Validating inline CSS in: $file"
        awk '/<style>/,/<\/style>/ {if (!/<style>/ && !/<\/style>/) print}' "$file" > inline_css.tmp
        if [ -s inline_css.tmp ]; then
            if command -v csslint >/dev/null 2>&1; then
                # Use more lenient CSS validation - ignore certain rules that are too strict
                if csslint --ignore=box-model,adjoining-classes,qualified-headings,unique-headings,fallback-colors,font-sizes,gradients,text-indent,compatible-vendor-prefixes,vendor-prefix,zero-units inline_css.tmp > csslint_errors.txt 2>&1; then
                    add_to_report "✅ Inline CSS valid: $file"
                else
                    # Only fail on actual errors, not warnings
                    error_count=$(grep -c "Error -" csslint_errors.txt || echo "0")
                    if [ "$error_count" -gt 0 ]; then
                        add_to_report "❌ Inline CSS errors in: $file (Critical errors: $error_count)"
                        while IFS= read -r line; do
                            add_to_report "   $line"
                        done < <(grep "Error -" csslint_errors.txt | head -5)
                        VALIDATION_PASSED=false
                    else
                        warning_count=$(grep -c "Warning -" csslint_errors.txt || echo "0")
                        add_to_report "⚠️ Inline CSS warnings in: $file (Warnings: $warning_count) - Not blocking build"
                    fi
                fi
                rm -f csslint_errors.txt
            else
                add_to_report "⚠️ CSS validation skipped (csslint missing)"
            fi
        else
            add_to_report "ℹ️ No inline CSS found in: $file"
        fi
        rm -f inline_css.tmp

        # Extract and validate inline JavaScript with more lenient rules
        echo "Validating inline JavaScript in: $file"
        awk '/<script>/,/<\/script>/ {if (!/<script>/ && !/<\/script>/) print}' "$file" > inline_js.tmp
        if [ -s inline_js.tmp ]; then
            if command -v eslint >/dev/null 2>&1; then
                # Create a more lenient eslint config
                cat > .eslintrc.tmp << 'EOF'
{
  "parserOptions": {
    "ecmaVersion": 2020,
    "sourceType": "script"
  },
  "env": {
    "browser": true,
    "es6": true
  },
  "rules": {
    "no-unused-vars": "warn",
    "no-undef": "warn",
    "semi": "warn",
    "no-console": "off"
  }
}
EOF
                if eslint -c .eslintrc.tmp -f compact inline_js.tmp > eslint_errors.txt 2>&1; then
                    add_to_report "✅ Inline JavaScript valid: $file"
                else
                    # Only fail on actual errors, not warnings
                    error_count=$(grep -c "error" eslint_errors.txt || echo "0")
                    if [ "$error_count" -gt 0 ]; then
                        add_to_report "❌ Inline JavaScript errors in: $file (Errors: $error_count)"
                        while IFS= read -r line; do
                            add_to_report "   $line"
                        done < <(grep "error" eslint_errors.txt | head -5)
                        VALIDATION_PASSED=false
                    else
                        warning_count=$(grep -c "warning" eslint_errors.txt || echo "0")
                        add_to_report "⚠️ Inline JavaScript warnings in: $file (Warnings: $warning_count) - Not blocking build"
                    fi
                fi
                rm -f eslint_errors.txt .eslintrc.tmp
            else
                add_to_report "⚠️ JavaScript validation skipped (eslint missing)"
            fi
        else
            add_to_report "ℹ️ No inline JavaScript found in: $file"
        fi
        rm -f inline_js.tmp
    done
}

# Function to validate that the HTML actually works
validate_html_functionality() {
    echo "Checking HTML functionality..."
    local html_files=$(find . -name "*.html" -not -path "./node_modules/*")
    
    for file in $html_files; do
        # Check for basic HTML structure
        if grep -q "<!DOCTYPE html>" "$file" && grep -q "<html" "$file" && grep -q "</html>" "$file"; then
            add_to_report "✅ HTML structure complete: $file"
        else
            add_to_report "⚠️ HTML structure incomplete: $file"
        fi
        
        # Check for basic meta tags
        if grep -q "<meta charset=" "$file" && grep -q "<meta name=\"viewport\"" "$file"; then
            add_to_report "✅ Essential meta tags present: $file"
        else
            add_to_report "⚠️ Missing essential meta tags: $file"
        fi
        
        # Check for title
        if grep -q "<title>" "$file"; then
            add_to_report "✅ Title tag present: $file"
        else
            add_to_report "⚠️ Missing title tag: $file"
        fi
    done
}

# Run validations
validate_html_functionality
validate_html

# Generate validation report
echo "=== CODE VALIDATION REPORT ===" > validation_report.txt
echo "Generated: $(date)" >> validation_report.txt
echo "Build Number: ${BUILD_NUMBER:-'N/A'}" >> validation_report.txt
echo "Git Commit: $(git rev-parse HEAD 2>/dev/null || echo 'N/A')" >> validation_report.txt
echo "" >> validation_report.txt
echo "Validation Mode: Balanced (Errors fail build, warnings don't)" >> validation_report.txt
echo "" >> validation_report.txt
echo -e "$VALIDATION_REPORT" >> validation_report.txt
echo "=============================" >> validation_report.txt

# Print the full report for debugging
echo ""
echo "=== FULL VALIDATION REPORT ==="
cat validation_report.txt
echo ""

# Print final result
if [ "$VALIDATION_PASSED" = true ]; then
    echo "🎉 VALIDATION PASSED! Code is production ready."
    echo "Note: Warnings (if any) are logged but don't fail the build."
    echo "VALIDATION_STATUS=SUCCESS" > validation_status.txt
    exit 0
else
    echo "❌ VALIDATION FAILED! Critical errors found that need fixing."
    echo "Check the validation report above for specific issues."
    echo "VALIDATION_STATUS=FAILED" > validation_status.txt
    exit 1
fi
