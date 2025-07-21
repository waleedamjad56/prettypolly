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
        
        # Check syntax first with Python interpreter
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
            add_to_report "⚠️ flake8 not available, skipping advanced Python validation"
        fi
    done
}

# Validate HTML files for structural errors
validate_html() {
    echo "📄 Validating HTML files..."
    local html_files=$(find . -name "*.html" -not -path "./node_modules/*" -not -path "./.git/*")

    if [ -z "$html_files" ]; then
        add_to_report "ℹ️ No HTML files found to validate"
        return 0
    fi

    for file in $html_files; do
        echo "Checking HTML file: $file"
        
        # Check basic HTML structure
        if grep -q "<!DOCTYPE html>" "$file" && grep -q "<html" "$file" && grep -q "</html>" "$file"; then
            add_to_report "✅ HTML structure complete: $file"
        else
            add_to_report "⚠️ HTML structure incomplete (minor): $file"
        fi

        # Use htmlhint for critical structural errors only
        if command -v htmlhint >/dev/null 2>&1; then
            # Only check for critical tag pairing issues
            if htmlhint --rules tag-pair,tag-self-close "$file" > htmlhint_critical.txt 2>&1; then
                add_to_report "✅ HTML critical checks passed: $file"
            else
                # Check if there are actual critical errors
                if grep -q "error" htmlhint_critical.txt; then
                    add_to_report "❌ CRITICAL HTML structural error in: $file"
                    while IFS= read -r line; do
                        add_to_report "   $line"
                    done < <(grep "error" htmlhint_critical.txt | head -5)
                    VALIDATION_PASSED=false
                else
                    add_to_report "✅ HTML validation passed: $file"
                fi
            fi
            rm -f htmlhint_critical.txt
        else
            add_to_report "⚠️ htmlhint not available, skipping HTML validation"
        fi
    done
}

# Validate CSS files for parsing errors
validate_css() {
    echo "🎨 Validating CSS files..."
    local css_files=$(find . -name "*.css" -not -path "./node_modules/*" -not -path "./.git/*")

    if [ -z "$css_files" ]; then
        add_to_report "ℹ️ No CSS files found to validate"
        return 0
    fi

    for file in $css_files; do
        echo "Checking CSS file: $file"
        
        if command -v csslint >/dev/null 2>&1; then
            # Only check for parsing errors (critical)
            if csslint --errors=parsing-error --format=compact "$file" > csslint_critical.txt 2>&1; then
                add_to_report "✅ CSS parsing valid: $file"
            else
                # Check if there are actual parsing errors
                if grep -q "Error" csslint_critical.txt; then
                    add_to_report "❌ CRITICAL CSS parsing error in: $file"
                    while IFS= read -r line; do
                        add_to_report "   $line"
                    done < <(grep "Error" csslint_critical.txt | head -5)
                    VALIDATION_PASSED=false
                else
                    add_to_report "✅ CSS validation passed: $file"
                fi
            fi
            rm -f csslint_critical.txt
        else
            add_to_report "⚠️ csslint not available, skipping CSS validation"
        fi
    done
}

# Validate JavaScript files for syntax errors
validate_js() {
    echo "⚡ Validating JavaScript files..."
    local js_files=$(find . -name "*.js" -not -path "./node_modules/*" -not -path "./.git/*")

    if [ -z "$js_files" ]; then
        add_to_report "ℹ️ No JavaScript files found to validate"
        return 0
    fi

    for file in $js_files; do
        echo "Checking JavaScript file: $file"
        
        if command -v eslint >/dev/null 2>&1; then
            # Create minimal config for syntax checking only
            cat > .eslintrc.critical << 'EOF'
{
  "parserOptions": {
    "ecmaVersion": 2020,
    "sourceType": "script"
  },
  "env": {
    "browser": true,
    "es6": true,
    "node": true
  },
  "rules": {}
}
EOF
            # Only check for syntax errors
            if node -c "$file" 2>js_syntax_errors.txt; then
                add_to_report "✅ JavaScript syntax valid: $file"
            else
                add_to_report "❌ CRITICAL JavaScript syntax error in: $file"
                while IFS= read -r line; do
                    add_to_report "   $line"
                done < js_syntax_errors.txt
                VALIDATION_PASSED=false
            fi
            rm -f js_syntax_errors.txt .eslintrc.critical
        else
            # Fallback to node syntax check
            if node -c "$file" 2>js_fallback_errors.txt; then
                add_to_report "✅ JavaScript syntax valid: $file"
            else
                add_to_report "❌ CRITICAL JavaScript syntax error in: $file"
                while IFS= read -r line; do
                    add_to_report "   $line"
                done < js_fallback_errors.txt
                VALIDATION_PASSED=false
            fi
            rm -f js_fallback_errors.txt
        fi
    done
}

# Validate PHP files for syntax errors
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
            # Check PHP syntax
            if php -l "$file" > php_syntax_check.txt 2>&1; then
                add_to_report "✅ PHP syntax valid: $file"
            else
                add_to_report "❌ CRITICAL PHP syntax error in: $file"
                while IFS= read -r line; do
                    add_to_report "   $line"
                done < <(grep -v "No syntax errors detected" php_syntax_check.txt)
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
echo "📋 Focus: Critical errors that prevent code execution"
echo "⚠️ Warnings and minor issues will not fail the build"
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
echo "Validation Mode: Critical Errors Only" >> validation_report.txt
echo "- ✅ = Validation passed" >> validation_report.txt
echo "- ❌ = Critical error (build fails)" >> validation_report.txt
echo "- ⚠️  = Warning/minor issue (build continues)" >> validation_report.txt
echo "- ℹ️  = Information" >> validation_report.txt
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
    echo "Code is ready for deployment."
    echo "VALIDATION_STATUS=SUCCESS" > validation_status.txt
    exit 0
else
    echo "❌ BUILD FAILED - Critical errors must be fixed!"
    echo "Check the validation report above for specific issues."
    echo "VALIDATION_STATUS=FAILED" > validation_status.txt
    exit 1
fi
