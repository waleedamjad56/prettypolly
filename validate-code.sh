#!/bin/bash
set -e

VALIDATION_PASSED=true
VALIDATION_REPORT=""

add_to_report() {
    VALIDATION_REPORT="$VALIDATION_REPORT\n$1"
    echo "$1"
}

# Set up Python virtual environment if Python files exist
setup_python_env() {
    local py_files=$(find . -name "*.py" -not -path "./node_modules/*" -not -path "./.git/*" | head -1)
    if [ -n "$py_files" ]; then
        echo "🐍 Setting up Python 3.10 virtual environment..."
        if command -v python3.10 >/dev/null 2>&1; then
            python3.10 -m venv venv
        else
            python3 -m venv venv
        fi
        source venv/bin/activate
        # Upgrade pip in virtual environment
        pip install --upgrade pip
        # Install requirements if they exist
        if [ -f requirements.txt ]; then
            echo "📦 Installing Python dependencies from requirements.txt..."
            pip install -r requirements.txt
        fi
        add_to_report "✅ Python virtual environment set up successfully"
    fi
}

# Validate Python files for critical errors only
validate_python() {
    echo "🐍 Validating Python files..."
    local py_files=$(find . -name "*.py" -not -path "./node_modules/*" -not -path "./.git/*")
    
    if [ -z "$py_files" ]; then
        add_to_report "ℹ️ No Python files found to validate"
        return 0
    fi

    for file in $py_files; do
        echo "Checking Python file: $file"
        
        # Check syntax first with Python interpreter - THIS IS CRITICAL
        if python3 -m py_compile "$file" 2>python_syntax_errors.txt; then
            add_to_report "✅ Python syntax valid: $file"
        else
            add_to_report "❌ CRITICAL Python syntax error in: $file"
            while IFS= read -r line; do
                add_to_report "   $line"
            done < python_syntax_errors.txt
            VALIDATION_PASSED=false
        fi
        rm -f python_syntax_errors.txt

        # Use flake8 for critical errors only (E9xx - syntax errors, F82x - undefined names)
        if command -v flake8 >/dev/null 2>&1; then
            if flake8 --select=E9,F821,F822,F823 --exit-zero "$file" > flake8_critical.txt 2>&1; then
                if [ -s flake8_critical.txt ]; then
                    add_to_report "❌ CRITICAL Python error in: $file"
                    while IFS= read -r line; do
                        add_to_report "   $line"
                    done < flake8_critical.txt
                    VALIDATION_PASSED=false
                else
                    add_to_report "✅ Python critical checks passed: $file"
                fi
            fi
            rm -f flake8_critical.txt
        else
            add_to_report "ℹ️ flake8 not available, using basic syntax check only"
        fi
    done
}

# Validate HTML files for CRITICAL structural errors ONLY
validate_html() {
    echo "📄 Validating HTML files..."
    local html_files=$(find . -name "*.html" -not -path "./node_modules/*" -not -path "./.git/*")

    if [ -z "$html_files" ]; then
        add_to_report "ℹ️ No HTML files found to validate"
        return 0
    fi

    for file in $html_files; do
        echo "Checking HTML file: $file"
        
        # Basic structure check - INFORMATIONAL ONLY, NOT CRITICAL
        if grep -q "<!DOCTYPE html>" "$file" && grep -q "<html" "$file" && grep -q "</html>" "$file"; then
            add_to_report "✅ HTML basic structure present: $file"
        else
            add_to_report "ℹ️ HTML structure may be incomplete (not critical): $file"
        fi

        # Check for CRITICAL parsing errors only - malformed tags that break parsing
        local critical_errors=false
        
        # Check for unclosed critical tags that would break the page
        if grep -q "<html" "$file" && ! grep -q "</html>" "$file"; then
            add_to_report "❌ CRITICAL: Missing closing </html> tag in: $file"
            critical_errors=true
        fi
        
        if grep -q "<head" "$file" && ! grep -q "</head>" "$file"; then
            add_to_report "❌ CRITICAL: Missing closing </head> tag in: $file"
            critical_errors=true
        fi
        
        if grep -q "<body" "$file" && ! grep -q "</body>" "$file"; then
            add_to_report "❌ CRITICAL: Missing closing </body> tag in: $file"
            critical_errors=true
        fi

        # Use htmlhint ONLY for critical parsing errors, ignore warnings
        if command -v htmlhint >/dev/null 2>&1; then
            # Only check for critical tag pairing issues that break parsing
            htmlhint --rules tag-pair "$file" > htmlhint_output.txt 2>&1 || true
            
            # Only fail on actual ERROR lines, ignore warnings
            if grep -qi "error.*tag.*not.*closed\|error.*unexpected.*tag" htmlhint_output.txt; then
                add_to_report "❌ CRITICAL HTML parsing error in: $file"
                # Only show actual ERROR lines, not warnings
                grep -i "error.*tag.*not.*closed\|error.*unexpected.*tag" htmlhint_output.txt | head -3 | while IFS= read -r line; do
                    add_to_report "   $line"
                done
                critical_errors=true
            fi
            rm -f htmlhint_output.txt
        fi
        
        # Set validation status based on critical errors
        if [ "$critical_errors" = true ]; then
            VALIDATION_PASSED=false
        else
            add_to_report "✅ HTML critical validation passed: $file"
        fi
    done
}

# Validate CSS files for CRITICAL parsing errors ONLY
validate_css() {
    echo "🎨 Validating CSS files..."
    local css_files=$(find . -name "*.css" -not -path "./node_modules/*" -not -path "./.git/*")

    if [ -z "$css_files" ]; then
        add_to_report "ℹ️ No CSS files found to validate"
        return 0
    fi

    for file in $css_files; do
        echo "Checking CSS file: $file"
        
        # Basic syntax check for critical errors
        local critical_css_error=false
        
        # Check for unclosed braces
        local open_braces=$(grep -o '{' "$file" | wc -l)
        local close_braces=$(grep -o '}' "$file" | wc -l)
        
        if [ "$open_braces" -ne "$close_braces" ]; then
            add_to_report "❌ CRITICAL CSS parsing error: Mismatched braces in $file"
            add_to_report "   Open braces: $open_braces, Close braces: $close_braces"
            critical_css_error=true
        fi
        
        if command -v csslint >/dev/null 2>&1; then
            # Only check for parsing errors (critical), ignore all warnings
            csslint --errors=parsing-error --format=compact "$file" > csslint_output.txt 2>&1 || true
            
            # Only fail on actual parsing ERROR lines
            if grep -qi "error.*parsing" csslint_output.txt; then
                add_to_report "❌ CRITICAL CSS parsing error in: $file"
                grep -i "error.*parsing" csslint_output.txt | head -3 | while IFS= read -r line; do
                    add_to_report "   $line"
                done
                critical_css_error=true
            fi
            rm -f csslint_output.txt
        fi
        
        if [ "$critical_css_error" = true ]; then
            VALIDATION_PASSED=false
        else
            add_to_report "✅ CSS critical validation passed: $file"
        fi
    done
}

# Validate JavaScript files for CRITICAL syntax errors ONLY
validate_js() {
    echo "⚡ Validating JavaScript files..."
    local js_files=$(find . -name "*.js" -not -path "./node_modules/*" -not -path "./.git/*")

    if [ -z "$js_files" ]; then
        add_to_report "ℹ️ No JavaScript files found to validate"
        return 0
    fi

    for file in $js_files; do
        echo "Checking JavaScript file: $file"
        
        # Only check for syntax errors - these are CRITICAL
        if command -v node >/dev/null 2>&1; then
            if node -c "$file" 2>js_syntax_errors.txt; then
                add_to_report "✅ JavaScript syntax valid: $file"
            else
                add_to_report "❌ CRITICAL JavaScript syntax error in: $file"
                while IFS= read -r line; do
                    add_to_report "   $line"
                done < js_syntax_errors.txt
                VALIDATION_PASSED=false
            fi
            rm -f js_syntax_errors.txt
        else
            add_to_report "⚠️ Node.js not available, skipping JavaScript validation"
        fi
    done
}

# Validate PHP files for CRITICAL syntax errors ONLY
validate_php() {
    echo "🐘 Validating PHP files..."
    local php_files=$(find . -name "*.php" -not -path "./node_modules/*" -not -path "./.git/*")

    if [ -z "$php_files" ]; then
        add_to_report "ℹ️ No PHP files found to validate"
        return 0
    fi

    for file in $php_files; do
        echo "Checking PHP file: $file"
        
        if command -v php >/dev/null 2>&1; then
            # Check PHP syntax - CRITICAL errors only
            if php -l "$file" > php_syntax_check.txt 2>&1; then
                add_to_report "✅ PHP syntax valid: $file"
            else
                add_to_report "❌ CRITICAL PHP syntax error in: $file"
                # Only show actual syntax errors, not warnings
                while IFS= read -r line; do
                    if [[ "$line" != *"No syntax errors detected"* ]]; then
                        add_to_report "   $line"
                    fi
                done < php_syntax_check.txt
                VALIDATION_PASSED=false
            fi
            rm -f php_syntax_check.txt
        else
            add_to_report "⚠️ PHP not available, skipping PHP validation"
        fi
    done
}

# Main execution
echo "🚀 Starting Critical Code Validation..."
echo "📋 Focus: ONLY critical errors that prevent code execution"
echo "⚠️ Warnings, minor issues, and style problems are IGNORED"
echo ""

# Set up Python environment
setup_python_env

# Run all validations
validate_python
validate_css  
validate_html
validate_js
validate_php

# Generate comprehensive validation report
echo "" > validation_report.txt
echo "=== CRITICAL CODE VALIDATION REPORT ===" >> validation_report.txt
echo "Generated: $(date)" >> validation_report.txt
echo "Build Number: ${BUILD_NUMBER:-'N/A'}" >> validation_report.txt
echo "Git Commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'N/A')" >> validation_report.txt
echo "" >> validation_report.txt
echo "Validation Mode: CRITICAL ERRORS ONLY" >> validation_report.txt
echo "- ✅ = Validation passed" >> validation_report.txt
echo "- ❌ = Critical error (build fails)" >> validation_report.txt
echo "- ⚠️  = Warning/minor issue (build continues)" >> validation_report.txt
echo "- ℹ️  = Information (build continues)" >> validation_report.txt
echo "" >> validation_report.txt
echo -e "$VALIDATION_REPORT" >> validation_report.txt
echo "" >> validation_report.txt
echo "=============================" >> validation_report.txt

# Display the report
echo ""
echo "=== VALIDATION REPORT ==="
cat validation_report.txt
echo ""

# Clean up virtual environment if we created it
if [ -d "venv" ]; then
    deactivate 2>/dev/null || true
fi

# Final result
if [ "$VALIDATION_PASSED" = true ]; then
    echo "🎉 BUILD PASSED - No critical errors found!"
    echo "Minor issues and warnings are ignored in critical validation mode."
    echo "VALIDATION_STATUS=SUCCESS" > validation_status.txt
    exit 0
else
    echo "❌ BUILD FAILED - Critical errors must be fixed!"
    echo "Only critical errors that prevent execution cause build failure."
    echo "VALIDATION_STATUS=FAILED" > validation_status.txt
    exit 1
fi
