#!/bin/bash

# Code validation script for HTML, CSS, and JS (No Python dependencies)
# Exit on any error
set -e

VALIDATION_PASSED=true
VALIDATION_REPORT=""

echo "=== Starting Code Validation ==="

# Function to add to validation report
add_to_report() {
    VALIDATION_REPORT="$VALIDATION_REPORT\n$1"
}

# Function to validate HTML files
validate_html() {
    echo "Validating HTML files..."
    local html_files=$(find . -name "*.html" -not -path "./node_modules/*")

    if [ -z "$html_files" ]; then
        echo "No HTML files found to validate."
        return 0
    fi

    local html_errors=0

    for file in $html_files; do
        echo "Validating HTML: $file"

        # Using htmlhint for HTML validation
        if command -v htmlhint >/dev/null 2>&1; then
            if ! htmlhint "$file" 2>/dev/null; then
                echo "❌ HTML validation failed for: $file"
                add_to_report "❌ HTML validation failed for: $file"
                html_errors=$((html_errors + 1))
                VALIDATION_PASSED=false
            else
                echo "✅ HTML validation passed for: $file"
                add_to_report "✅ HTML validation passed for: $file"
            fi
        else
            echo "⚠️  htmlhint not available, skipping HTML validation"
        fi

        # Try html-validate if available
        if command -v html-validate >/dev/null 2>&1; then
            if ! html-validate "$file" 2>/dev/null; then
                echo "❌ HTML structure validation failed for: $file"
                add_to_report "❌ HTML structure validation failed for: $file"
                html_errors=$((html_errors + 1))
                VALIDATION_PASSED=false
            else
                echo "✅ HTML structure validation passed for: $file"
                add_to_report "✅ HTML structure validation passed for: $file"
            fi
        fi

        # Additional check with tidy for HTML5 compliance
        if command -v tidy >/dev/null 2>&1; then
            if ! tidy -q -e "$file" 2>/dev/null; then
                echo "⚠️  HTML structure warnings for: $file (not blocking)"
                add_to_report "⚠️  HTML structure warnings for: $file"
            fi
        fi
    done

    if [ $html_errors -eq 0 ]; then
        echo "✅ All HTML files passed validation"
    else
        echo "❌ $html_errors HTML files failed validation"
    fi
}

# Function to validate CSS files
validate_css() {
    echo "Validating CSS files..."
    local css_files=$(find . -name "*.css" -not -path "./node_modules/*")

    if [ -z "$css_files" ]; then
        echo "No CSS files found to validate."
        return 0
    fi

    local css_errors=0

    for file in $css_files; do
        echo "Validating CSS: $file"

        # Using csslint
        if command -v csslint >/dev/null 2>&1; then
            if ! csslint --format=compact "$file" 2>/dev/null; then
                echo "❌ CSS validation failed for: $file"
                add_to_report "❌ CSS validation failed for: $file"
                css_errors=$((css_errors + 1))
                VALIDATION_PASSED=false
            else
                echo "✅ CSS validation passed for: $file"
                add_to_report "✅ CSS validation passed for: $file"
            fi
        else
            echo "⚠️  csslint not available, skipping CSS validation"
        fi

        # Additional check with stylelint (if config exists)
        if command -v stylelint >/dev/null 2>&1 && ([ -f ".stylelintrc" ] || [ -f ".stylelintrc.json" ]); then
            if ! stylelint "$file" 2>/dev/null; then
                echo "⚠️  CSS style warnings for: $file (not blocking)"
                add_to_report "⚠️  CSS style warnings for: $file"
            fi
        fi
    done

    if [ $css_errors -eq 0 ]; then
        echo "✅ All CSS files passed validation"
    else
        echo "❌ $css_errors CSS files failed validation"
    fi
}

# Function to validate JavaScript files
validate_js() {
    echo "Validating JavaScript files..."
    local js_files=$(find . -name "*.js" -not -path "./node_modules/*")

    if [ -z "$js_files" ]; then
        echo "No JavaScript files found to validate."
        return 0
    fi

    local js_errors=0

    for file in $js_files; do
        echo "Validating JS: $file"

        # Using jshint for basic syntax checking
        if command -v jshint >/dev/null 2>&1; then
            if ! jshint "$file" 2>/dev/null; then
                echo "❌ JavaScript validation failed for: $file"
                add_to_report "❌ JavaScript validation failed for: $file"
                js_errors=$((js_errors + 1))
                VALIDATION_PASSED=false
            else
                echo "✅ JavaScript validation passed for: $file"
                add_to_report "✅ JavaScript validation passed for: $file"
            fi
        else
            echo "⚠️  jshint not available, skipping JavaScript validation"
        fi

        # Additional check with ESLint (if config exists)
        if command -v eslint >/dev/null 2>&1 && ([ -f ".eslintrc" ] || [ -f ".eslintrc.json" ] || [ -f ".eslintrc.js" ]); then
            if ! eslint "$file" 2>/dev/null; then
                echo "⚠️  JavaScript style warnings for: $file (not blocking)"
                add_to_report "⚠️  JavaScript style warnings for: $file"
            fi
        fi
    done

    if [ $js_errors -eq 0 ]; then
        echo "✅ All JavaScript files passed validation"
    else
        echo "❌ $js_errors JavaScript files failed validation"
    fi
}

# Function to check file structure
validate_structure() {
    echo "Validating project structure..."

    # Check if index.html exists
    if [ -f "index.html" ]; then
        echo "✅ index.html found"
        add_to_report "✅ index.html found"
    else
        echo "⚠️  index.html not found (may not be required)"
        add_to_report "⚠️  index.html not found"
    fi

    # Check for common directories
    if [ -d "css" ] || [ -d "styles" ] || ls *.css 1> /dev/null 2>&1; then
        echo "✅ CSS files found"
        add_to_report "✅ CSS files found"
    fi

    if [ -d "js" ] || [ -d "javascript" ] || [ -d "scripts" ] || ls *.js 1> /dev/null 2>&1; then
        echo "✅ JavaScript files found"
        add_to_report "✅ JavaScript files found"
    fi

    # Check for proper file extensions
    local total_files=$(find . -type f \( -name "*.html" -o -name "*.css" -o -name "*.js" \) -not -path "./node_modules/*" | wc -l)
    echo "📊 Total web files found: $total_files"
    add_to_report "📊 Total web files found: $total_files"
}

# Function to check for common issues
validate_common_issues() {
    echo "Checking for common issues..."

    # Check for mixed content (http in https)
    if grep -r "http://" . --include="*.html" --include="*.css" --include="*.js" --exclude-dir=node_modules 2>/dev/null; then
        echo "⚠️  HTTP links found - consider using HTTPS"
        add_to_report "⚠️  HTTP links found - consider using HTTPS"
    fi

    # Check for missing alt attributes in images
    if grep -r "<img" . --include="*.html" --exclude-dir=node_modules | grep -v "alt=" 2>/dev/null; then
        echo "⚠️  Images without alt attributes found"
        add_to_report "⚠️  Images without alt attributes found"
    fi

    # Check for inline styles (should be in CSS files)
    if grep -r "style=" . --include="*.html" --exclude-dir=node_modules 2>/dev/null; then
        echo "⚠️  Inline styles found - consider moving to CSS files"
        add_to_report "⚠️  Inline styles found - consider moving to CSS files"
    fi
}

# Run all validations
validate_structure
validate_html
validate_css
validate_js
validate_common_issues

echo "=== Validation Complete ==="

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

