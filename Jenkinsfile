pipeline {
    agent any
    
    environment {
        BUILD_TIMESTAMP = sh(script: 'date "+%Y-%m-%d %H:%M:%S"', returnStdout: true).trim()
        VALIDATION_STATUS = ''
        GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
    }
    
    triggers {
        githubPush()
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "🔄 Checking out code from repository..."
                    echo "Build #${BUILD_NUMBER} started at ${BUILD_TIMESTAMP}"
                    
                    try {
                        checkout scm
                        echo "✅ Code checkout successful"
                        echo "📍 Git commit: ${GIT_COMMIT_SHORT}"
                    } catch (Exception e) {
                        echo "❌ Checkout failed: ${e.getMessage()}"
                        currentBuild.result = 'FAILURE'
                        error("Repository checkout failed")
                    }
                }
            }
        }
        
        stage('Pre-Validation Check') {
            steps {
                script {
                    echo "🔍 Checking for web files..."
                    
                    def htmlFiles = sh(script: 'find . -name "*.html" -not -path "./node_modules/*" | wc -l', returnStdout: true).trim()
                    def cssFiles = sh(script: 'find . -name "*.css" -not -path "./node_modules/*" | wc -l', returnStdout: true).trim()
                    def jsFiles = sh(script: 'find . -name "*.js" -not -path "./node_modules/*" | wc -l', returnStdout: true).trim()
                    
                    echo "📊 Found files - HTML: ${htmlFiles}, CSS: ${cssFiles}, JS: ${jsFiles}"
                    
                    if (htmlFiles.toInteger() == 0 && cssFiles.toInteger() == 0 && jsFiles.toInteger() == 0) {
                        echo "⚠️ No web files found to validate"
                        env.VALIDATION_STATUS = 'SKIPPED'
                    } else {
                        echo "✅ Web files found, proceeding with validation"
                    }
                }
            }
        }
        
        stage('Code Validation') {
            when {
                not { environment name: 'VALIDATION_STATUS', value: 'SKIPPED' }
            }
            steps {
                script {
                    echo "🔍 Starting comprehensive code validation..."
                    echo "📋 Validation includes: HTML structure, CSS syntax, JavaScript syntax"
                    
                    try {
                        // Make validation script executable
                        sh 'chmod +x validate-code.sh'
                        
                        // Run validation with detailed output
                        def validationResult = sh(
                            script: './validate-code.sh',
                            returnStatus: true
                        )
                        
                        if (validationResult == 0) {
                            env.VALIDATION_STATUS = 'SUCCESS'
                            echo "✅ All validations passed!"
                            echo "🎉 Code is ready for deployment"
                        } else {
                            env.VALIDATION_STATUS = 'FAILED'
                            echo "❌ Critical validation errors found!"
                            echo "🛑 Build stopped to prevent broken website deployment"
                            
                            // Display validation report if available
                            if (fileExists('validation_report.txt')) {
                                echo "📄 Validation Report:"
                                sh 'cat validation_report.txt'
                            }
                            
                            currentBuild.result = 'FAILURE'
                            error("Critical validation errors detected. Fix errors before deployment.")
                        }
                        
                    } catch (Exception e) {
                        env.VALIDATION_STATUS = 'ERROR'
                        echo "💥 Validation script execution failed: ${e.getMessage()}"
                        
                        // Check if validation tools are available
                        echo "🔧 Checking validation tools availability..."
                        sh '''
                            echo "Node.js: $(node --version 2>/dev/null || echo 'Not found')"
                            echo "ESLint: $(eslint --version 2>/dev/null || echo 'Not found')"
                            echo "HTMLHint: $(htmlhint --version 2>/dev/null || echo 'Not found')"
                            echo "CSSLint: $(csslint --version 2>/dev/null || echo 'Not found')"
                        '''
                        
                        currentBuild.result = 'FAILURE'
                        error("Validation process failed")
                    }
                }
            }
        }
        
        stage('Build Summary') {
            steps {
                script {
                    echo "📊 Build Summary"
                    echo "=================="
                    echo "Build Number: ${BUILD_NUMBER}"
                    echo "Build Time: ${BUILD_TIMESTAMP}"
                    echo "Git Commit: ${GIT_COMMIT_SHORT}"
                    echo "Validation Status: ${env.VALIDATION_STATUS}"
                    echo "Build Result: ${currentBuild.result ?: 'SUCCESS'}"
                    echo "=================="
                    
                    // Create build summary file
                    writeFile file: 'build-summary.txt', text: """
Build Summary Report
===================
Build Number: ${BUILD_NUMBER}
Build Timestamp: ${BUILD_TIMESTAMP}
Git Commit: ${GIT_COMMIT_SHORT}
Validation Status: ${env.VALIDATION_STATUS}
Build Result: ${currentBuild.result ?: 'SUCCESS'}
Duration: ${currentBuild.durationString}
===================
"""
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🔄 Processing build artifacts..."
                
                // Archive validation report
                if (fileExists('validation_report.txt')) {
                    archiveArtifacts artifacts: 'validation_report.txt', 
                                   allowEmptyArchive: true,
                                   fingerprint: true
                    echo "📄 Validation report archived"
                }
                
                // Archive validation status
                if (fileExists('validation_status.txt')) {
                    archiveArtifacts artifacts: 'validation_status.txt', 
                                   allowEmptyArchive: true,
                                   fingerprint: true
                }
                
                // Archive build summary
                if (fileExists('build-summary.txt')) {
                    archiveArtifacts artifacts: 'build-summary.txt', 
                                   allowEmptyArchive: true,
                                   fingerprint: true
                }
                
                // Publish HTML report if available
                if (fileExists('validation_report.txt')) {
                    try {
                        publishHTML([
                            allowMissing: false,
                            alwaysLinkToLastBuild: true,
                            keepAll: true,
                            reportDir: '.',
                            reportFiles: 'validation_report.txt',
                            reportName: 'Code Validation Report',
                            reportTitles: "Build #${BUILD_NUMBER} Validation"
                        ])
                        echo "📊 HTML report published"
                    } catch (Exception e) {
                        echo "⚠️ Failed to publish HTML report: ${e.getMessage()}"
                    }
                }
            }
        }
        
        success {
            script {
                echo "🎉 BUILD COMPLETED SUCCESSFULLY!"
                echo "✅ All stages passed"
                echo "🚀 Code is validated and ready"
                
                // Display recent build history
                echo "📈 Recent Build Status:"
                def recentBuilds = currentBuild.getPreviousBuild()?.getNumber() ?: 'N/A'
                echo "Previous Build: #${recentBuilds}"
            }
        }
        
        failure {
            script {
                echo "💥 BUILD FAILED!"
                echo "❌ One or more stages failed"
                echo "🔍 Check the validation report for details"
                echo "💡 Fix the reported issues and retry"
                
                // Provide helpful debugging info
                if (env.VALIDATION_STATUS == 'FAILED') {
                    echo "🛠️ Common fixes:"
                    echo "   - Check HTML syntax and structure"
                    echo "   - Verify CSS syntax and selectors"
                    echo "   - Fix JavaScript syntax errors"
                    echo "   - Ensure proper DOCTYPE and meta tags"
                }
            }
        }
        
        unstable {
            script {
                echo "⚠️ BUILD UNSTABLE"
                echo "🔧 Some issues detected but build continued"
            }
        }
        
        cleanup {
            script {
                echo "🧹 Cleaning up temporary files..."
                
                // Clean up temporary validation files
                sh '''
                    rm -f inline_css.tmp inline_js.tmp
                    rm -f htmlhint_errors.txt csslint_errors.txt eslint_errors.txt
                    rm -f .eslintrc.tmp
                '''
                
                // Optionally clean workspace (uncomment if needed)
                // cleanWs()
                
                echo "✨ Cleanup completed"
            }
        }
    }
}
