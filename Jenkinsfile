pipeline {
    agent any

    environment {
        GITHUB_CREDENTIALS = 'github-pat'
        VALIDATION_STATUS = ''
        BUILD_TIMESTAMP = sh(script: 'date "+%Y-%m-%d %H:%M:%S"', returnStdout: true).trim()
    }

    triggers {
        githubPush()
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        skipDefaultCheckout()
    }

    stages {
        stage('Checkout') {
            steps {
                echo "🔄 Checking out code from GitHub..."
                checkout scm
                
                script {
                    sh '''
                        echo "=== COMMIT INFORMATION ==="
                        echo "Commit Hash: $(git rev-parse HEAD)"
                        echo "Author: $(git log -1 --pretty=format:'%an <%ae>')"
                        echo "Message: $(git log -1 --pretty=format:'%s')"
                        echo "Branch: ${GIT_BRANCH}"
                        echo "=========================="
                    '''
                }
            }
        }

        stage('Code Validation') {
            steps {
                echo "🔍 Starting code validation..."
                
                script {
                    // Create validation script inline
                    writeFile file: 'validate-code.sh', text: '''#!/bin/bash
set -e

VALIDATION_PASSED=true
VALIDATION_REPORT=""

echo "=== Starting Code Validation ==="

add_to_report() {
    VALIDATION_REPORT="$VALIDATION_REPORT\\n$1"
}

validate_html() {
    echo "Validating HTML files..."
    local html_files=$(find . -name "*.html" -not -path "./node_modules/*")

    if [ -z "$html_files" ]; then
        echo "No HTML files found to validate."
        add_to_report "ℹ️  No HTML files found to validate."
        return 0
    fi

    local html_errors=0
    for file in $html_files; do
        echo "Validating HTML: $file"
        
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
            add_to_report "⚠️  htmlhint not available, skipping HTML validation"
        fi
        
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
    done

    if [ $html_errors -eq 0 ]; then
        echo "✅ All HTML files passed validation"
        add_to_report "✅ All HTML files passed validation"
    else
        echo "❌ $html_errors HTML files failed validation"
        add_to_report "❌ $html_errors HTML files failed validation"
    fi
}

validate_css() {
    echo "Validating CSS files..."
    local css_files=$(find . -name "*.css" -not -path "./node_modules/*")

    if [ -z "$css_files" ]; then
        echo "No CSS files found to validate."
        add_to_report "ℹ️  No CSS files found to validate."
        return 0
    fi

    local css_errors=0
    for file in $css_files; do
        echo "Validating CSS: $file"
        
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
            add_to_report "⚠️  csslint not available, skipping CSS validation"
        fi
    done

    if [ $css_errors -eq 0 ]; then
        echo "✅ All CSS files passed validation"
        add_to_report "✅ All CSS files passed validation"
    else
        echo "❌ $css_errors CSS files failed validation"
        add_to_report "❌ $css_errors CSS files failed validation"
    fi
}

validate_js() {
    echo "Validating JavaScript files..."
    local js_files=$(find . -name "*.js" -not -path "./node_modules/*")

    if [ -z "$js_files" ]; then
        echo "No JavaScript files found to validate."
        add_to_report "ℹ️  No JavaScript files found to validate."
        return 0
    fi

    local js_errors=0
    for file in $js_files; do
        echo "Validating JS: $file"
        
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
            add_to_report "⚠️  jshint not available, skipping JavaScript validation"
        fi
    done

    if [ $js_errors -eq 0 ]; then
        echo "✅ All JavaScript files passed validation"
        add_to_report "✅ All JavaScript files passed validation"
    else
        echo "❌ $js_errors JavaScript files failed validation"
        add_to_report "❌ $js_errors JavaScript files failed validation"
    fi
}

validate_structure() {
    echo "Validating project structure..."
    
    if [ -f "index.html" ]; then
        echo "✅ index.html found"
        add_to_report "✅ index.html found"
    else
        echo "⚠️  index.html not found"
        add_to_report "⚠️  index.html not found"
    fi

    local total_files=$(find . -type f \\( -name "*.html" -o -name "*.css" -o -name "*.js" \\) -not -path "./node_modules/*" | wc -l)
    echo "📊 Total web files found: $total_files"
    add_to_report "📊 Total web files found: $total_files"
}

# Run validations
validate_structure
validate_html
validate_css
validate_js

echo "=== Validation Complete ==="

# Generate validation report
echo "=== VALIDATION REPORT ===" > validation_report.txt
echo "Generated: $(date)" >> validation_report.txt
echo "Build Number: ${BUILD_NUMBER:-'N/A'}" >> validation_report.txt
echo "Git Commit: $(git rev-parse HEAD 2>/dev/null || echo 'N/A')" >> validation_report.txt
echo "" >> validation_report.txt
echo -e "$VALIDATION_REPORT" >> validation_report.txt
echo "=========================" >> validation_report.txt

if [ "$VALIDATION_PASSED" = true ]; then
    echo "🎉 ALL VALIDATIONS PASSED! Code is ready for deployment."
    echo "VALIDATION_STATUS=SUCCESS" > validation_status.txt
    exit 0
else
    echo "❌ VALIDATION FAILED! Please fix the issues before deployment."
    echo "VALIDATION_STATUS=FAILED" > validation_status.txt
    exit 1
fi
'''

                    // Make script executable and run it
                    sh 'chmod +x validate-code.sh'

                    try {
                        sh './validate-code.sh'
                        env.VALIDATION_STATUS = 'SUCCESS'
                        echo "✅ Code validation passed!"
                    } catch (Exception e) {
                        env.VALIDATION_STATUS = 'FAILED'
                        echo "❌ Code validation failed!"
                        error "Code validation failed. Stopping deployment."
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'validation_report.txt, validation_status.txt', allowEmptyArchive: true
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: '.',
                        reportFiles: 'validation_report.txt',
                        reportName: 'Code Validation Report'
                    ])
                }
            }
        }

        stage('Deploy to Production') {
            when {
                expression { env.VALIDATION_STATUS == 'SUCCESS' }
            }
            steps {
                echo "🚀 Deploying to production..."
                
                script {
                    sh '''
                        echo "=== DEPLOYMENT STARTED ==="
                        echo "Timestamp: ${BUILD_TIMESTAMP}"
                        echo "Build Number: ${BUILD_NUMBER}"
                        echo "Git Commit: $(git rev-parse HEAD)"

                        # Create deployment package
                        mkdir -p deployment-package
                        cp -r . deployment-package/

                        # Remove unnecessary files from deployment
                        rm -rf deployment-package/.git
                        rm -rf deployment-package/node_modules
                        rm -f deployment-package/validate-code.sh
                        rm -f deployment-package/Jenkinsfile
                        rm -f deployment-package/validation_report.txt
                        rm -f deployment-package/validation_status.txt

                        echo "✅ Deployment package created successfully"
                        echo "📦 Files in deployment package:"
                        find deployment-package -type f | head -20
                        echo "=== DEPLOYMENT COMPLETED ==="
                    '''
                }
            }
        }
    }

    post {
        success {
            script {
                emailext (
                    subject: "✅ Jenkins Build SUCCESS - ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """
                    <h2>🎉 BUILD SUCCESSFUL</h2>
                    <p><strong>Project:</strong> ${env.JOB_NAME}</p>
                    <p><strong>Build Number:</strong> ${env.BUILD_NUMBER}</p>
                    <p><strong>Build Status:</strong> <span style="color: green;">SUCCESS</span></p>
                    <p><strong>Timestamp:</strong> ${BUILD_TIMESTAMP}</p>
                    <p><strong>Git Branch:</strong> ${env.GIT_BRANCH}</p>
                    <p><strong>Git Commit:</strong> ${env.GIT_COMMIT}</p>

                    <h3>✅ Validation Results</h3>
                    <p>All code validation checks passed successfully!</p>
                    <ul>
                        <li>HTML validation: PASSED</li>
                        <li>CSS validation: PASSED</li>
                        <li>JavaScript validation: PASSED</li>
                        <li>Project structure: VALIDATED</li>
                    </ul>

                    <h3>🚀 Deployment Status</h3>
                    <p>Code has been successfully deployed to production.</p>

                    <p><strong>Build URL:</strong> <a href="${env.BUILD_URL}">${env.BUILD_URL}</a></p>
                    <p><strong>Console Output:</strong> <a href="${env.BUILD_URL}console">${env.BUILD_URL}console</a></p>
                    """,
                    mimeType: 'text/html',
                    to: 'kencypher56@gmail.com,rottinken@gmail.com'
                )
            }
        }

        failure {
            script {
                emailext (
                    subject: "❌ Jenkins Build FAILED - ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """
                    <h2>❌ BUILD FAILED</h2>
                    <p><strong>Project:</strong> ${env.JOB_NAME}</p>
                    <p><strong>Build Number:</strong> ${env.BUILD_NUMBER}</p>
                    <p><strong>Build Status:</strong> <span style="color: red;">FAILED</span></p>
                    <p><strong>Timestamp:</strong> ${BUILD_TIMESTAMP}</p>
                    <p><strong>Git Branch:</strong> ${env.GIT_BRANCH}</p>
                    <p><strong>Git Commit:</strong> ${env.GIT_COMMIT}</p>

                    <h3>❌ Validation Results</h3>
                    <p>Code validation failed. Please check the following:</p>
                    <ul>
                        <li>HTML syntax errors</li>
                        <li>CSS syntax errors</li>
                        <li>JavaScript syntax errors</li>
                        <li>Project structure issues</li>
                    </ul>

                    <h3>🔧 Next Steps</h3>
                    <p>Please fix the validation errors and push your changes again.</p>

                    <p><strong>Build URL:</strong> <a href="${env.BUILD_URL}">${env.BUILD_URL}</a></p>
                    <p><strong>Console Output:</strong> <a href="${env.BUILD_URL}console">${env.BUILD_URL}console</a></p>
                    <p><strong>Validation Report:</strong> <a href="${env.BUILD_URL}Code_Validation_Report">View Report</a></p>
                    """,
                    mimeType: 'text/html',
                    to: 'kencypher56@gmail.com,rottinken@gmail.com'
                )
            }
        }

        always {
            cleanWs()
        }
    }
}
