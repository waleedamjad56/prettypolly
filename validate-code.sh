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

# Get only USER-CREATED files (exclude system/library/generated files)
get_user_files() {
    local extension="$1"
    
    # Find files but exclude common system/library paths
    find . -maxdepth 3 -name "*.$extension" \
        -not -path "./venv/*" \
        -not -path "./env/*" \
        -not -path "./.venv/*" \
        -not -path "./node_modules/*" \
        -not -path "./.git/*" \
        -not -path "./site-packages/*" \
        -not -path "./lib/*" \
        -not -path "./build/*" \
        -not -path "./dist/*" \
        -not -path "./__pycache__/*" \
        -not -path "./vendor/*" \
        -not -name "__init__.py" \
        -not -name "setup.py" \
        -not -name "conftest.py" \
        -not -name "test_*.py" \
        -not -name "*_test.py" \
        -not -name "manage.py" \
        -not -name "wsgi.py" \
        -not -name "asgi.py" \
        -not -name "settings.py" \
        -not -name "urls.py" \
        -not -name "admin.py" \
        -not -name "models.py" \
        -not -name "views.py" \
        -not -name "forms.py" \
        -not -name "apps.py" 2>/dev/null
}

# Check for required tools (only what we actually need)
check_required_tools() {
    echo "🔧 Checking validation tools..."
    
    # Only check tools for file types that actually exist
    local user_py_files=$(get_user_files "py")
    local user_js_files=$(get_user_files "js")
    local user_php_files=$(get_user_files "php")
    
    if [ -n "$user_py_files" ]; then
        if command -v python3 >/dev/null 2>&1; then
            add_to_report "✅ Python3 found for validation"
        else
            add_missing_tool "❌ CRITICAL: Python3 needed for your .py files"
        fi
    fi
    
    if [ -n "$user_js_files" ]; then
        if command -v node >/dev/null 2>&1; then
            add_to_report "✅ Node.js found for JavaScript validation"
        else
            add_missing_tool "⚠️ Node.js missing - JavaScript validation skipped"
        fi
    fi
    
    if [ -n "$user_php_files" ]; then
        if command -v php >/dev/null 2>&1; then
            add_to_report "✅ PHP found for validation"
        else
            add_missing_tool "⚠️ PHP missing - PHP validation skipped"
        fi
    fi
}

# Quick project structure check
check_project_structure() {
    echo "📁 Quick project scan..."
    
    # Count actual user files
    local py_count=$(get_user_files "py" | wc -l)
    local html_count=$(get_user_files "html" | wc -l)
    local css_count=$(get_user_files "css" | wc -l)
    local js_count=$(get_user_files "js" | wc -l)
    local php_count=$(get_user_files "php" | wc -l)
    
    add_to_report "📊 Found: ${py_count} Python, ${html_count} HTML, ${css_count} CSS, ${js_count} JS, ${php_count} PHP files"
    
    # Only check for requirements if Python files exist
    if [ "$py_count" -gt 0 ] && [ ! -f "requirements.txt" ]; then
        add_missing_file "ℹ️ Consider adding requirements.txt for Python dependencies"
    fi
}

# Fast Python validation - ONLY your files
validate_python() {
    local py_files=$(get_user_files "py")
    
    if [ -z "$py_files" ]; then
        add_to_report "ℹ️ No user Python files to validate"
        return 0
    fi

    echo "🐍 Validating YOUR Python files..."
    local files_count=$(echo "$py_files" | wc -l)
    add_to_report "📊 Checking $files_count Python files you created"

    for file in $py_files; do
        echo "Validating: $file"
        
        # CRITICAL: Syntax check only
        if python3 -m py_compile "$file" 2>python_errors.tmp; then
            add_to_report "✅ $file - syntax OK"
        else
            add_critical_error "❌ CRITICAL syntax error in: $file"
            while IFS= read -r line; do
                add_critical_error "   $line"
            done < python_errors.tmp
        fi
        rm -f python_errors.tmp
    done
}

# Fast HTML validation
validate_html() {
    local html_files=$(get_user_files "html")

    if [ -z "$html_files" ]; then
        add_to_report "ℹ️ No HTML files to validate"
        return 0
    fi

    echo "📄 Validating HTML files..."
    local files_count=$(echo "$html_files" | wc -l)
    add_to_report "📊 Checking $files_count HTML files"

    for file in $html_files; do
        echo "Validating: $file"
        
        # Basic structure check
        if grep -q "<html" "$file" && grep -q "</html>" "$file"; then
            add_to_report "✅ $file - structure OK"
        else
            add_warning "⚠️ $file - missing HTML tags"
        fi
        
        # Critical: Check for unclosed major tags
        if grep -q "<html" "$file" && ! grep -q "</html>" "$file"; then
            add_critical_error "❌ CRITICAL: Missing </html> in $file"
        fi
        if grep -q "<head" "$file" && ! grep -q "</head>" "$file"; then
            add_critical_error "❌ CRITICAL: Missing </head> in $file"
        fi
        if grep -q "<body" "$file" && ! grep -q "</body>" "$file"; then
            add_critical_error "❌ CRITICAL: Missing </body> in $file"
        fi
    done
}

# Fast CSS validation
validate_css() {
    local css_files=$(get_user_files "css")

    if [ -z "$css_files" ]; then
        add_to_report "ℹ️ No CSS files to validate"
        return 0
    fi

    echo "🎨 Validating CSS files..."
    local files_count=$(echo "$css_files" | wc -l)
    add_to_report "📊 Checking $files_count CSS files"

    for file in $css_files; do
        echo "Validating: $file"
        
        # Critical: Check brace matching
        local open_braces=$(grep -o '{' "$file" | wc -l)
        local close_braces=$(grep -o '}' "$file" | wc -l)
        
        if [ "$open_braces" -eq "$close_braces" ]; then
            add_to_report "✅ $file - syntax OK"
        else
            add_critical_error "❌ CRITICAL: Mismatched braces in $file (${open_braces} open, ${close_braces} close)"
        fi
    done
}

# Fast JavaScript validation
validate_js() {
    local js_files=$(get_user_files "js")

    if [ -z "$js_files" ]; then
        add_to_report "ℹ️ No JavaScript files to validate"
        return 0
    fi

    echo "⚡ Validating JavaScript files..."
    local files_count=$(echo "$js_files" | wc -l)
    add_to_report "📊 Checking $files_count JavaScript files"

    for file in $js_files; do
        echo "Validating: $file"
        
        if command -v node >/dev/null 2>&1; then
            if node -c "$file" 2>js_errors.tmp; then
                add_to_report "✅ $file - syntax OK"
            else
                add_critical_error "❌ CRITICAL JavaScript error in: $file"
                while IFS= read -r line; do
                    add_critical_error "   $line"
                done < js_errors.tmp
            fi
            rm -f js_errors.tmp
        else
            add_to_report "⚠️ $file - Node.js not available, skipped"
        fi
    done
}

# Fast PHP validation
validate_php() {
    local php_files=$(get_user_files "php")

    if [ -z "$php_files" ]; then
        add_to_report "ℹ️ No PHP files to validate"
        return 0
    fi

    echo "🐘 Validating PHP files..."
    local files_count=$(echo "$php_files" | wc -l)
    add_to_report "📊 Checking $files_count PHP files"

    for file in $php_files; do
        echo "Validating: $file"
        
        if command -v php >/dev/null 2>&1; then
            if php -l "$file" >/dev/null 2>&1; then
                add_to_report "✅ $file - syntax OK"
            else
                add_critical_error "❌ CRITICAL PHP syntax error in: $file"
                php -l "$file" 2>&1 | grep -v "No syntax errors" | while IFS= read -r line; do
                    add_critical_error "   $line"
                done
            fi
        else
            add_to_report "⚠️ $file - PHP not available, skipped"
        fi
    done
}

# Generate simple report
generate_report() {
    echo "" > validation_report.txt
    echo "=== FAST CODE VALIDATION REPORT ===" >> validation_report.txt
    echo "Generated: $(date)" >> validation_report.txt
    echo "Working Directory: $(pwd)" >> validation_report.txt
    echo "" >> validation_report.txt
    
    echo "=== VALIDATION RESULTS ===" >> validation_report.txt
    echo -e "$VALIDATION_REPORT" >> validation_report.txt
    echo "" >> validation_report.txt
    
    if [ -n "$CRITICAL_ERRORS_REPORT" ]; then
        echo "=== CRITICAL ERRORS ===" >> validation_report.txt
        echo -e "$CRITICAL_ERRORS_REPORT" >> validation_report.txt
        echo "" >> validation_report.txt
    fi
    
    if [ -n "$WARNING_REPORT" ]; then
        echo "=== WARNINGS ===" >> validation_report.txt
        echo -e "$WARNING_REPORT" >> validation_report.txt
        echo "" >> validation_report.txt
    fi
}

# Main execution
echo "🚀 Fast Code Validation - USER FILES ONLY"
echo "📋 Scanning only files you created (excluding libraries/system files)"
echo ""

# Quick checks
check_required_tools
check_project_structure

# Fast validation
validate_python
validate_css  
validate_html
validate_js
validate_php

# Generate report
generate_report
cat validation_report.txt

# Summary
total_critical=$(echo -e "$CRITICAL_ERRORS_REPORT" | grep -c "❌" || echo 0)
total_warnings=$(echo -e "$WARNING_REPORT" | grep -c "⚠️" || echo 0)

echo ""
echo "📊 SUMMARY: $total_critical critical errors, $total_warnings warnings"

if [ "$VALIDATION_PASSED" = true ]; then
    echo "🎉 VALIDATION PASSED!"
    exit 0
else
    echo "❌ VALIDATION FAILED - Fix critical errors!"
    exit 1
fi
