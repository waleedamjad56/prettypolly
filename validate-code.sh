#!/bin/bash
set -e

VALIDATION_PASSED=true
VALIDATION_REPORT=""
WARNING_REPORT=""
MISSING_FILES_REPORT=""
MISSING_TOOLS_REPORT=""
CRITICAL_ERRORS_REPORT=""

add_to_report() {
    VALIDATION_REPORT="$VALIDATION_REPORT\n$1"
    echo "$1"
}

add_warning() {
    WARNING_REPORT="$WARNING_REPORT\n$1"
    echo "$1"
}

add_missing_file() {
    MISSING_FILES_REPORT="$MISSING_FILES_REPORT\n$1"
    echo "$1"
}

add_missing_tool() {
    MISSING_TOOLS_REPORT="$MISSING_TOOLS_REPORT\n$1"
    echo "$1"
}

add_critical_error() {
    CRITICAL_ERRORS_REPORT="$CRITICAL_ERRORS_REPORT\n$1"
    add_to_report "$1"
    VALIDATION_PASSED=false
}

# Check for required tools and report missing ones
check_required_tools() {
    echo "🔧 Checking for required validation tools..."
    
    local tools_checked=0
    local tools_missing=0
    
    # Check Python
    if command -v python3 >/dev/null 2>&1 || command -v python3.10 >/dev/null 2>&1; then
        add_to_report "✅ Python3 found"
        tools_checked=$((tools_checked + 1))
    else
        add_missing_tool "❌ CRITICAL: Python3 not found - Required for Python validation"
        tools_missing=$((tools_missing + 1))
    fi
    
    # Check Node.js for JavaScript validation
    if command -v node >/dev/null 2>&1; then
        add_to_report "✅ Node.js found for JavaScript validation"
        tools_checked=$((tools_checked + 1))
    else
        add_missing_tool "⚠️ Node.js not found - JavaScript syntax validation will be skipped"
        tools_missing=$((tools_missing + 1))
    fi
    
    # Check PHP
    if command -v php >/dev/null 2>&1; then
        add_to_report "✅ PHP found for PHP validation"
        tools_checked=$((tools_checked + 1))
    else
        add_missing_tool "⚠️ PHP not found - PHP syntax validation will be skipped"
        tools_missing=$((tools_missing + 1))
    fi
    
    # Check optional linting tools
    if command -v flake8 >/dev/null 2>&1; then
        add_to_report "✅ flake8 found for enhanced Python validation"
    else
        add_missing_tool "⚠️ flake8 not found - Using basic Python syntax check only"
    fi
    
    if command -v htmlhint >/dev/null 2>&1; then
        add_to_report "✅ htmlhint found for HTML validation"
    else
        add_missing_tool "⚠️ htmlhint not found - Using basic HTML structure check only"
    fi
    
    if command -v csslint >/dev/null 2>&1; then
        add_to_report "✅ csslint found for CSS validation"
    else
        add_missing_tool "⚠️ csslint not found - Using basic CSS brace matching only"
    fi
    
    add_to_report "📊 Tools Status: $tools_checked found, $tools_missing missing/optional"
}

# Check for expected project files
check_project_structure() {
    echo "📁 Checking project structure and expected files..."
    
    # Check for common configuration files
    local expected_files=("requirements.txt" "package.json" "composer.json" "Dockerfile" ".gitignore" "README.md")
    
    for file in "${expected_files[@]}"; do
        if [ -f "$file" ]; then
            add_to_report "✅ Found: $file"
        else
            add_missing_file "ℹ️ Optional file missing: $file (Location: ./$file)"
        fi
    done
    
    # Check for source code directories
    local expected_dirs=("src" "lib" "app" "public" "static")
    local found_dirs=0
    
    for dir in "${expected_dirs[@]}"; do
        if [ -d "$dir" ]; then
            add_to_report "✅ Found directory: $dir"
            found_dirs=$((found_dirs + 1))
        fi
    done
    
    if [ $found_dirs -eq 0 ]; then
        add_missing_file "ℹ️ No common source directories found (src/, lib/, app/, public/, static/)"
    fi
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

    local files_count=$(echo "$py_files" | wc -l)
    add_to_report "📊 Found $files_count Python files to validate"

    for file in $py_files; do
        echo "Checking Python file: $file"
        
        # Check file size and warn if too large
        local file_size=$(wc -l < "$file")
        if [ "$file_size" -gt 1000 ]; then
            add_warning "⚠️ Large file detected: $file ($file_size lines) - Consider splitting into smaller modules"
        fi
        
        # Check syntax first with Python interpreter - THIS IS CRITICAL
        if python3 -m py_compile "$file" 2>python_syntax_errors.txt; then
            add_to_report "✅ Python syntax valid: $file"
        else
            add_critical_error "❌ CRITICAL Python syntax error in: $file"
            local line_num=1
            while IFS= read -r line; do
                add_critical_error "   Line $line_num: $line"
                line_num=$((line_num + 1))
            done < python_syntax_errors.txt
        fi
        rm -f python_syntax_errors.txt

        # Use flake8 for critical errors only (E9xx - syntax errors, F82x - undefined names)
        if command -v flake8 >/dev/null 2>&1; then
            # Check for critical errors
            flake8 --select=E9,F821,F822,F823 --exit-zero "$file" > flake8_critical.txt 2>&1
            if [ -s flake8_critical.txt ]; then
                add_critical_error "❌ CRITICAL Python error in: $file"
                while IFS= read -r line; do
                    add_critical_error "   $line"
                done < flake8_critical.txt
            else
                add_to_report "✅ Python critical checks passed: $file"
            fi
            rm -f flake8_critical.txt
            
            # Check for warnings (style issues, complexity)
            flake8 --select=W,E1,E2,E3,C,N --exit-zero "$file" > flake8_warnings.txt 2>&1
            if [ -s flake8_warnings.txt ]; then
                add_warning "⚠️ Python style warnings in: $file"
                local warning_count=$(wc -l < flake8_warnings.txt)
                add_warning "   Found $warning_count warnings:"
                head -10 flake8_warnings.txt | while IFS= read -r line; do
                    add_warning "   $line"
                done
                if [ "$warning_count" -gt 10 ]; then
                    add_warning "   ... and $((warning_count - 10)) more warnings"
                fi
            fi
            rm -f flake8_warnings.txt
        else
            add_to_report "ℹ️ flake8 not available, using basic syntax check only"
        fi
        
        # Check for potential security issues
        if grep -n "eval\|exec\|__import__" "$file" > security_check.txt 2>&1; then
            add_warning "⚠️ Potential security concerns in: $file"
            while IFS= read -r line; do
                add_warning "   $line"
            done < security_check.txt
        fi
        rm -f security_check.txt
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

    local files_count=$(echo "$html_files" | wc -l)
    add_to_report "📊 Found $files_count HTML files to validate"

    for file in $html_files; do
        echo "Checking HTML file: $file"
        
        # Check file size
        local file_size=$(wc -l < "$file")
        if [ "$file_size" -gt 500 ]; then
            add_warning "⚠️ Large HTML file: $file ($file_size lines) - Consider splitting or optimizing"
        fi
        
        # Basic structure check - INFORMATIONAL ONLY, NOT CRITICAL
        local has_doctype=$(grep -n "<!DOCTYPE html>" "$file" || true)
        local has_html_open=$(grep -n "<html" "$file" || true)
        local has_html_close=$(grep -n "</html>" "$file" || true)
        
        if [ -n "$has_doctype" ] && [ -n "$has_html_open" ] && [ -n "$has_html_close" ]; then
            add_to_report "✅ HTML basic structure present: $file"
        else
            add_warning "⚠️ HTML structure may be incomplete: $file"
            [ -z "$has_doctype" ] && add_warning "   Missing DOCTYPE declaration"
            [ -z "$has_html_open" ] && add_warning "   Missing opening <html> tag"
            [ -z "$has_html_close" ] && add_warning "   Missing closing </html> tag"
        fi

        # Check for CRITICAL parsing errors only - malformed tags that break parsing
        local critical_errors=false
        
        # Check for unclosed critical tags that would break the page
        if grep -q "<html" "$file" && ! grep -q "</html>" "$file"; then
            local line_num=$(grep -n "<html" "$file" | cut -d: -f1)
            add_critical_error "❌ CRITICAL: Missing closing </html> tag in: $file (opened at line $line_num)"
            critical_errors=true
        fi
        
        if grep -q "<head" "$file" && ! grep -q "</head>" "$file"; then
            local line_num=$(grep -n "<head" "$file" | cut -d: -f1)
            add_critical_error "❌ CRITICAL: Missing closing </head> tag in: $file (opened at line $line_num)"
            critical_errors=true
        fi
        
        if grep -q "<body" "$file" && ! grep -q "</body>" "$file"; then
            local line_num=$(grep -n "<body" "$file" | cut -d: -f1)
            add_critical_error "❌ CRITICAL: Missing closing </body> tag in: $file (opened at line $line_num)"
            critical_errors=true
        fi

        # Use htmlhint ONLY for critical parsing errors, ignore warnings
        if command -v htmlhint >/dev/null 2>&1; then
            # Check for critical errors
            htmlhint --rules tag-pair "$file" > htmlhint_critical.txt 2>&1 || true
            if grep -qi "error.*tag.*not.*closed\|error.*unexpected.*tag" htmlhint_critical.txt; then
                add_critical_error "❌ CRITICAL HTML parsing error in: $file"
                grep -i "error.*tag.*not.*closed\|error.*unexpected.*tag" htmlhint_critical.txt | head -5 | while IFS= read -r line; do
                    add_critical_error "   $line"
                done
                critical_errors=true
            fi
            rm -f htmlhint_critical.txt
            
            # Check for warnings
            htmlhint --rules alt-require,title-require "$file" > htmlhint_warnings.txt 2>&1 || true
            if grep -qi "warning" htmlhint_warnings.txt; then
                add_warning "⚠️ HTML accessibility warnings in: $file"
                grep -i "warning" htmlhint_warnings.txt | head -5 | while IFS= read -r line; do
                    add_warning "   $line"
                done
            fi
            rm -f htmlhint_warnings.txt
        fi
        
        # Check for missing alt attributes in images
        if grep -n "<img[^>]*>" "$file" | grep -v "alt=" > missing_alt.txt 2>/dev/null && [ -s missing_alt.txt ]; then
            add_warning "⚠️ Images missing alt attributes in: $file"
            while IFS= read -r line; do
                add_warning "   $line"
            done < missing_alt.txt
        fi
        rm -f missing_alt.txt
        
        if [ "$critical_errors" = false ]; then
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

    local files_count=$(echo "$css_files" | wc -l)
    add_to_report "📊 Found $files_count CSS files to validate"

    for file in $css_files; do
        echo "Checking CSS file: $file"
        
        # Check file size
        local file_size=$(wc -l < "$file")
        if [ "$file_size" -gt 1000 ]; then
            add_warning "⚠️ Large CSS file: $file ($file_size lines) - Consider splitting or minifying"
        fi
        
        # Basic syntax check for critical errors
        local critical_css_error=false
        
        # Check for unclosed braces with line numbers
        local open_braces=$(grep -n '{' "$file" | wc -l)
        local close_braces=$(grep -n '}' "$file" | wc -l)
        
        if [ "$open_braces" -ne "$close_braces" ]; then
            add_critical_error "❌ CRITICAL CSS parsing error: Mismatched braces in $file"
            add_critical_error "   Open braces: $open_braces, Close braces: $close_braces"
            
            # Show line numbers of opening braces without closing ones
            local brace_count=0
            local line_num=1
            while IFS= read -r line; do
                local opens=$(echo "$line" | grep -o '{' | wc -l)
                local closes=$(echo "$line" | grep -o '}' | wc -l)
                brace_count=$((brace_count + opens - closes))
                if [ "$opens" -gt 0 ] && [ "$brace_count" -gt 0 ]; then
                    add_critical_error "   Potential unclosed brace starting at line $line_num: $line"
                fi
                line_num=$((line_num + 1))
            done < "$file"
            critical_css_error=true
        fi
        
        # Check for invalid property syntax
        if grep -n ":[[:space:]]*;" "$file" > invalid_props.txt 2>/dev/null && [ -s invalid_props.txt ]; then
            add_warning "⚠️ Empty CSS properties found in: $file"
            while IFS= read -r line; do
                add_warning "   Line $line"
            done < invalid_props.txt
        fi
        rm -f invalid_props.txt
        
        if command -v csslint >/dev/null 2>&1; then
            # Only check for parsing errors (critical), ignore all warnings
            csslint --errors=parsing-error --format=compact "$file" > csslint_critical.txt 2>&1 || true
            if grep -qi "error.*parsing" csslint_critical.txt; then
                add_critical_error "❌ CRITICAL CSS parsing error in: $file"
                grep -i "error.*parsing" csslint_critical.txt | head -5 | while IFS= read -r line; do
                    add_critical_error "   $line"
                done
                critical_css_error=true
            fi
            rm -f csslint_critical.txt
            
            # Check for warnings
            csslint --warnings=duplicate-properties,empty-rules --format=compact "$file" > csslint_warnings.txt 2>&1 || true
            if grep -qi "warning" csslint_warnings.txt; then
                add_warning "⚠️ CSS optimization warnings in: $file"
                grep -i "warning" csslint_warnings.txt | head -5 | while IFS= read -r line; do
                    add_warning "   $line"
                done
            fi
            rm -f csslint_warnings.txt
        fi
        
        if [ "$critical_css_error" = false ]; then
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

    local files_count=$(echo "$js_files" | wc -l)
    add_to_report "📊 Found $files_count JavaScript files to validate"

    for file in $js_files; do
        echo "Checking JavaScript file: $file"
        
        # Check file size
        local file_size=$(wc -l < "$file")
        if [ "$file_size" -gt 1000 ]; then
            add_warning "⚠️ Large JavaScript file: $file ($file_size lines) - Consider modularizing"
        fi
        
        # Only check for syntax errors - these are CRITICAL
        if command -v node >/dev/null 2>&1; then
            if node -c "$file" 2>js_syntax_errors.txt; then
                add_to_report "✅ JavaScript syntax valid: $file"
            else
                add_critical_error "❌ CRITICAL JavaScript syntax error in: $file"
                while IFS= read -r line; do
                    add_critical_error "   $line"
                done < js_syntax_errors.txt
            fi
            rm -f js_syntax_errors.txt
            
            # Check for potential issues (warnings)
            if grep -n "console\.log\|debugger\|alert(" "$file" > js_warnings.txt 2>/dev/null && [ -s js_warnings.txt ]; then
                add_warning "⚠️ Debug statements found in: $file"
                while IFS= read -r line; do
                    add_warning "   Line $line"
                done < js_warnings.txt
            fi
            rm -f js_warnings.txt
            
            # Check for security concerns
            if grep -n "eval\|innerHTML\|document\.write" "$file" > js_security.txt 2>/dev/null && [ -s js_security.txt ]; then
                add_warning "⚠️ Potential security concerns in: $file"
                while IFS= read -r line; do
                    add_warning "   Line $line"
                done < js_security.txt
            fi
            rm -f js_security.txt
            
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

    local files_count=$(echo "$php_files" | wc -l)
    add_to_report "📊 Found $files_count PHP files to validate"

    for file in $php_files; do
        echo "Checking PHP file: $file"
        
        # Check file size
        local file_size=$(wc -l < "$file")
        if [ "$file_size" -gt 1000 ]; then
            add_warning "⚠️ Large PHP file: $file ($file_size lines) - Consider refactoring"
        fi
        
        if command -v php >/dev/null 2>&1; then
            # Check PHP syntax - CRITICAL errors only
            if php -l "$file" > php_syntax_check.txt 2>&1; then
                add_to_report "✅ PHP syntax valid: $file"
            else
                add_critical_error "❌ CRITICAL PHP syntax error in: $file"
                while IFS= read -r line; do
                    if [[ "$line" != *"No syntax errors detected"* ]]; then
                        add_critical_error "   $line"
                    fi
                done < php_syntax_check.txt
            fi
            rm -f php_syntax_check.txt
            
            # Check for security issues
            if grep -n "\$_GET\|\$_POST\|\$_REQUEST" "$file" | grep -v "filter_\|htmlspecialchars\|mysqli_real_escape_string" > php_security.txt 2>/dev/null && [ -s php_security.txt ]; then
                add_warning "⚠️ Potential security concerns (unfiltered input) in: $file"
                while IFS= read -r line; do
                    add_warning "   Line $line"
                done < php_security.txt
            fi
            rm -f php_security.txt
            
        else
            add_to_report "⚠️ PHP not available, skipping PHP validation"
        fi
    done
}

# Generate detailed validation report
generate_detailed_report() {
    echo "" > validation_report.txt
    echo "=== COMPREHENSIVE CODE VALIDATION REPORT ===" >> validation_report.txt
    echo "Generated: $(date)" >> validation_report.txt
    echo "Build Number: ${BUILD_NUMBER:-'N/A'}" >> validation_report.txt
    echo "Git Commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'N/A')" >> validation_report.txt
    echo "Working Directory: $(pwd)" >> validation_report.txt
    echo "" >> validation_report.txt
    echo "Validation Mode: CRITICAL ERRORS + WARNINGS + MISSING ITEMS" >> validation_report.txt
    echo "- ✅ = Validation passed" >> validation_report.txt
    echo "- ❌ = Critical error (build fails)" >> validation_report.txt
    echo "- ⚠️  = Warning/minor issue (build continues)" >> validation_report.txt
    echo "- ℹ️  = Information (build continues)" >> validation_report.txt
    echo "" >> validation_report.txt
    
    # Main validation results
    echo "=== MAIN VALIDATION RESULTS ===" >> validation_report.txt
    echo -e "$VALIDATION_REPORT" >> validation_report.txt
    echo "" >> validation_report.txt
    
    # Critical errors section
    if [ -n "$CRITICAL_ERRORS_REPORT" ]; then
        echo "=== CRITICAL ERRORS (MUST FIX) ===" >> validation_report.txt
        echo -e "$CRITICAL_ERRORS_REPORT" >> validation_report.txt
        echo "" >> validation_report.txt
    fi
    
    # Warnings section
    if [ -n "$WARNING_REPORT" ]; then
        echo "=== WARNINGS AND RECOMMENDATIONS ===" >> validation_report.txt
        echo -e "$WARNING_REPORT" >> validation_report.txt
        echo "" >> validation_report.txt
    fi
    
    # Missing files section
    if [ -n "$MISSING_FILES_REPORT" ]; then
        echo "=== MISSING FILES AND DIRECTORIES ===" >> validation_report.txt
        echo -e "$MISSING_FILES_REPORT" >> validation_report.txt
        echo "" >> validation_report.txt
    fi
    
    # Missing tools section
    if [ -n "$MISSING_TOOLS_REPORT" ]; then
        echo "=== MISSING TOOLS AND DEPENDENCIES ===" >> validation_report.txt
        echo -e "$MISSING_TOOLS_REPORT" >> validation_report.txt
        echo "" >> validation_report.txt
    fi
    
    echo "=============================" >> validation_report.txt
}

# Main execution
echo "🚀 Starting Comprehensive Code Validation..."
echo "📋 Focus: Critical errors + Warnings + Missing files/tools"
echo ""

# Check tools and project structure first
check_required_tools
check_project_structure

# Set up Python environment
setup_python_env

# Run all validations
validate_python
validate_css  
validate_html
validate_js
validate_php

# Generate comprehensive validation report
generate_detailed_report

# Display the report
echo ""
echo "=== COMPREHENSIVE VALIDATION REPORT ==="
cat validation_report.txt
echo ""

# Clean up virtual environment if we created it
if [ -d "venv" ]; then
    deactivate 2>/dev/null || true
fi

# Generate summary statistics
total_warnings=$(echo -e "$WARNING_REPORT" | grep -c "⚠️" || echo 0)
total_critical=$(echo -e "$CRITICAL_ERRORS_REPORT" | grep -c "❌" || echo 0)
total_missing_tools=$(echo -e "$MISSING_TOOLS_REPORT" | grep -c "❌\|⚠️" || echo 0)
total_missing_files=$(echo -e "$MISSING_FILES_REPORT" | grep -c "ℹ️" || echo 0)

echo "📊 VALIDATION SUMMARY:"
echo "   Critical Errors: $total_critical"
echo "   Warnings: $total_warnings"
echo "   Missing Tools: $total_missing_tools"
echo "   Missing Files: $total_missing_files"
echo ""

# Final result
if [ "$VALIDATION_PASSED" = true ]; then
    echo "🎉 BUILD PASSED - No critical errors found!"
    if [ "$total_warnings" -gt 0 ]; then
        echo "⚠️ Note: $total_warnings warnings found (non-blocking)"
    fi
    echo "VALIDATION_STATUS=SUCCESS" > validation_status.txt
    echo "CRITICAL_ERRORS=$total_critical" >> validation_status.txt
    echo "WARNINGS=$total_warnings" >> validation_status.txt
    echo "MISSING_TOOLS=$total_missing_tools" >> validation_status.txt
    echo "MISSING_FILES=$total_missing_files" >> validation_status.txt
    exit 0
else
    echo "❌ BUILD FAILED - $total_critical critical errors must be fixed!"
    echo "Check the detailed report above for specific line numbers and locations."
    echo "VALIDATION_STATUS=FAILED" > validation_status.txt
    echo "CRITICAL_ERRORS=$total_critical" >> validation_status.txt
    echo "WARNINGS=$total_warnings" >> validation_status.txt
    echo "MISSING_TOOLS=$total_missing_tools" >> validation_status.txt
    echo "MISSING_FILES=$total_missing_files" >> validation_status.txt
    exit 1
fi
