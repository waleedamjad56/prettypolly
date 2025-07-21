#!/bin/bash
set -e

CRITICAL_ERRORS_FOUND=false
ERROR_REPORT=""

add_error() {
    ERROR_REPORT="$ERROR_REPORT\n$1"
    CRITICAL_ERRORS_FOUND=true
}

add_info() {
    ERROR_REPORT="$ERROR_REPORT\n$1"
}

# Validate Python files for CRITICAL syntax errors only
validate_python() {
    echo "🐍 Checking Python files for critical syntax errors..."
    local python_files=$(find . -name "*.py" -not -path "./.git/*" -not -path "./venv/*" -not -path "./__pycache__/*")

    if [ -z "$python_files" ]; then
        add_info "ℹ️ No Python files found"
        return 0
    fi

    for file in $python_files; do
        echo "Validating Python: $file"
        
        # Check for syntax errors (will cause crash)
        if ! python3 -m py_compile "$file" 2>/dev/null; then
            python3 -m py_compile "$file" 2>python_error.tmp || true
            add_error "🚨 PYTHON SYNTAX ERROR in $file:"
            add_error "$(cat python_error.tmp)"
            rm -f python_error.tmp
        else
            # Check for undefined variables and imports (will cause runtime crash)
            if command -v pyflakes >/dev/null 2>&1; then
                pyflakes_output=$(pyflakes "$file" 2>&1 | grep -E "(undefined name|imported but unused)" || true)
                if [ -n "$pyflakes_output" ]; then
                    critical_issues=$(echo "$pyflakes_output" | grep "undefined name" || true)
                    if [ -n "$critical_issues" ]; then
                        add_error "🚨 PYTHON UNDEFINED VARIABLES in $file (will cause NameError):"
                        add_error "$critical_issues"
                    fi
                fi
            fi
            add_info "✅ Python syntax OK: $file"
        fi
    done
}

# Validate HTML files for CRITICAL structural errors only  
validate_html() {
    echo "🌐 Checking HTML files for critical structural errors..."
    local html_files=$(find . -name "*.html" -not -path "./.git/*")

    if [ -z "$html_files" ]; then
        add_info "ℹ️ No HTML files found"
        return 0
    fi

    for file in $html_files; do
        echo "Validating HTML: $file"
        
        # Check for basic structure that would break rendering
        if ! grep -q "<!DOCTYPE" "$file"; then
            add_error "🚨 HTML MISSING DOCTYPE in $file (may cause rendering issues)"
        fi
        
        if ! grep -q "<html" "$file"; then
            add_error "🚨 HTML MISSING <html> tag in $file"
        fi
        
        # Check for unclosed critical tags that break page structure
        if command -v htmlhint >/dev/null 2>&1; then
            htmlhint_errors=$(htmlhint "$file" 2>&1 | grep -i "error" | head -5 || true)
            if [ -n "$htmlhint_errors" ]; then
                add_error "🚨 HTML STRUCTURE ERRORS in $file:"
                add_error "$htmlhint_errors"
            else
                add_info "✅ HTML structure OK: $file"
            fi
        else
            add_info "✅ HTML basic check OK: $file"
        fi
        
        # Check inline JavaScript for critical syntax errors
        if grep -q "<script" "$file"; then
            awk '/<script[^>]*>/,/<\/script>/ {if (!/<script/ && !/<\/script>/) print}' "$file" > js_inline.tmp
            if [ -s js_inline.tmp ]; then
                if command -v node >/dev/null 2>&1; then
                    if ! node -c js_inline.tmp 2>/dev/null; then
                        node -c js_inline.tmp 2>js_error.tmp || true
                        add_error "🚨 JAVASCRIPT SYNTAX ERROR in inline script in $file:"
                        add_error "$(cat js_error.tmp)"
                        rm -f js_error.tmp
                    fi
                fi
            fi
            rm -f js_inline.tmp
        fi
    done
}

# Validate CSS files for CRITICAL syntax errors only
validate_css() {
    echo "🎨 Checking CSS files for critical syntax errors..."
    local css_files=$(find . -name "*.css" -not -path "./.git/*")

    if [ -z "$css_files" ]; then
        add_info "ℹ️ No CSS files found"
        return 0
    fi

    for file in $css_files; do
        echo "Validating CSS: $file"
        
        # Check for basic syntax errors that break CSS parsing
        if command -v csslint >/dev/null 2>&1; then
            css_errors=$(csslint --format=compact --quiet --errors=parsing-errors "$file" 2>&1 | grep -i "error" || true)
            if [ -n "$css_errors" ]; then
                add_error "🚨 CSS PARSING ERRORS in $file:"
                add_error "$css_errors"
            else
                add_info "✅ CSS syntax OK: $file"
            fi
        else
            # Basic check for unmatched braces
            open_braces=$(grep -o "{" "$file" | wc -l)
            close_braces=$(grep -o "}" "$file" | wc -l)
            if [ "$open_braces" -ne "$close_braces" ]; then
                add_error "🚨 CSS BRACE MISMATCH in $file: $open_braces opening vs $close_braces closing"
            else
                add_info "✅ CSS basic structure OK: $file"
            fi
        fi
    done
}

# Validate JavaScript files for CRITICAL syntax errors only
validate_javascript() {
    echo "⚡ Checking JavaScript files for critical syntax errors..."
    local js_files=$(find . -name "*.js" -not -path "./.git/*" -not -path "./node_modules/*")

    if [ -z "$js_files" ]; then
        add_info "ℹ️ No JavaScript files found"
        return 0
    fi

    for file in $js_files; do
        echo "Validating JavaScript: $file"
        
        # Check for syntax errors that prevent execution
        if command -v node >/dev/null 2>&1; then
            if ! node -c "$file" 2>/dev/null; then
                node -c "$file" 2>js_error.tmp || true
                add_error "🚨 JAVASCRIPT SYNTAX ERROR in $file:"
                add_error "$(cat js_error.tmp)"
                rm -f js_error.tmp
            else
                add_info "✅ JavaScript syntax OK: $file"
            fi
        else
            add_info "⚠️ JavaScript validation skipped (Node.js not available)"
        fi
    done
}

# Validate PHP files for CRITICAL syntax errors only
validate_php() {
    echo "🐘 Checking PHP files for critical syntax errors..."
    local php_files=$(find . -name "*.php" -not -path "./.git/*")

    if [ -z "$php_files" ]; then
        add_info "ℹ️ No PHP files found"
        return 0
    fi

    for file in $php_files; do
        echo "Validating PHP: $file"
        
        # Check for syntax errors
        if command -v php >/dev/null 2>&1; then
            if ! php -l "$file" >/dev/null 2>&1; then
                php_error=$(php -l "$file" 2>&1 || true)
                add_error "🚨 PHP SYNTAX ERROR in $file:"
                add_error "$php_error"
            else
                add_info "✅ PHP syntax OK: $file"
            fi
        else
            add_info "⚠️ PHP validation skipped (PHP not available)"
        fi
    done
}

# Run all validations
echo "🔍 CRITICAL ERROR VALIDATION - Only checking for errors that cause crashes"
echo "========================================================================"

validate_python
validate_html  
validate_css
validate_javascript
validate_php

# Generate report
echo "CRITICAL ERRORS VALIDATION REPORT" > critical_errors.txt
echo "=================================" >> critical_errors.txt
echo "Generated: $(date)" >> critical_errors.txt
echo "Build: ${BUILD_NUMBER:-'N/A'}" >> critical_errors.txt
echo "Commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'N/A')" >> critical_errors.txt
echo "" >> critical_errors.txt
echo "Focus: Only syntax errors and critical issues that cause program crashes" >> critical_errors.txt
echo "" >> critical_errors.txt
echo -e "$ERROR_REPORT" >> critical_errors.txt
echo "=================================" >> critical_errors.txt

# Show report
echo ""
echo "📋 VALIDATION REPORT:"
cat critical_errors.txt
echo ""

# Final result
if [ "$CRITICAL_ERRORS_FOUND" = true ]; then
    echo "❌ CRITICAL ERRORS FOUND - These will cause program crashes!"
    echo "🛠️ Fix these errors before deployment"
    exit 1
else
    echo "✅ NO CRITICAL ERRORS FOUND - Code should run without crashing"
    echo "ℹ️ Note: Only checked for syntax errors and critical runtime issues"
    exit 0
fi
