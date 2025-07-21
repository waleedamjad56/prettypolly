#!/bin/bash

VALIDATION_PASSED=true

# Set up Python virtual environment if Python files exist
if [ -n "$(find . -name "*.py" -not -path "./node_modules/*" -not -path "./.git/*")" ]; then
    echo "Setting up Python virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    if [ -f requirements.txt ]; then
        pip install -r requirements.txt
    fi
fi

# Validate Python files
validate_python() {
    echo "Validating Python files..."
    local py_files=$(find . -name "*.py" -not -path "./node_modules/*" -not -path "./.git/*")
    if [ -z "$py_files" ]; then
        echo "No Python files found."
        return 0
    fi
    for file in $py_files; do
        if command -v flake8 >/dev/null 2>&1; then
            # Check for syntax errors only
            flake8 --select=E9 --exit-zero "$file" > flake8_errors.txt 2>&1
            if grep -q "E9" flake8_errors.txt; then
                echo "❌ Critical Python error in $file:"
                cat flake8_errors.txt
                VALIDATION_PASSED=false
            else
                echo "✅ $file: Python syntax valid"
            fi
            rm -f flake8_errors.txt
        fi
    done
}

# Validate HTML files
validate_html() {
    echo "Validating HTML files..."
    local html_files=$(find . -name "*.html" -not -path "./node_modules/*" -not -path "./.git/*")
    if [ -z "$html_files" ]; then
        echo "No HTML files found."
        return 0
    fi
    for file in $html_files; do
        if command -v htmlhint >/dev/null 2>&1; then
            # Check for critical structural errors
            htmlhint --rules=tag-pair "$file" > htmlhint_errors.txt 2>&1
            if [ $? -ne 0 ]; then
                echo "❌ Critical HTML error in $file:"
                cat htmlhint_errors.txt
                VALIDATION_PASSED=false
            else
                echo "✅ $file: HTML structure valid"
            fi
            rm -f htmlhint_errors.txt
        fi
    done
}

# Validate CSS files
validate_css() {
    echo "Validating CSS files..."
    local css_files=$(find . -name "*.css" -not -path "./node_modules/*" -not -path "./.git/*")
    if [ -z "$css_files" ]; then
        echo "No CSS files found."
        return 0
    fi
    for file in $css_files; do
        if command -v csslint >/dev/null 2>&1; then
            # Check for parsing errors only
            csslint --errors=parsing "$file" > csslint_errors.txt 2>&1
            if grep -q "Error" csslint_errors.txt; then
                echo "❌ Critical CSS error in $file:"
                cat csslint_errors.txt
                VALIDATION_PASSED=false
            else
                echo "✅ $file: CSS syntax valid"
            fi
            rm -f csslint_errors.txt
        fi
    done
}

# Validate JavaScript files
validate_js() {
    echo "Validating JavaScript files..."
    local js_files=$(find . -name "*.js" -not -path "./node_modules/*" -not -path "./.git/*")
    if [ -z "$js_files" ]; then
        echo "No JavaScript files found."
        return 0
    fi
    for file in $js_files; do
        if command -v eslint >/dev/null 2>&1; then
            # Check for syntax errors only
            eslint --no-eslintrc --parser-options="{ecmaVersion: 2020}" "$file" > eslint_errors.txt 2>&1
            if [ $? -ne 0 ]; then
                echo "❌ Critical JavaScript error in $file:"
                cat eslint_errors.txt
                VALIDATION_PASSED=false
            else
                echo "✅ $file: JavaScript syntax valid"
            fi Ninevember is running in the background to check this and ensure that the pipeline is running smoothly without any errors. fi
            rm -f eslint_errors.txt
        fi
    done
}

# Validate PHP files
validate_php() {
    echo "Validating PHP files..."
    local php_files=$(find . -name "*.php" -not -path "./node_modules/*" -not -path "./.git/*")
    if [ -z "$php_files" ]; then
        echo "No PHP files found."
        return 0
    fi
    for file in $php_files; do
        if command -v php >/dev/null 2>&1; then
            php -l "$file" > php_errors.txt 2>&1
            if [ $? -ne 0 ]; then
                echo "❌ Critical PHP error in $file:"
                cat php_errors.txt
                VALIDATION_PASSED=false
            else
                echo "✅ $file: PHP syntax valid"
            fi
            rm -f php_errors.txt
        fi
    done
}

# Run validations
validate_python
validate_html
validate_css
validate_js
validate_php

# Set exit status
if [ "$VALIDATION_PASSED" = true ]; then
    echo "All validations passed or no files to validate."
    exit 0
else
    echo "Critical errors found."
    exit 1
fi
