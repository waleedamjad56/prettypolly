pipeline {
    agent any
    
    environment {
        BUILD_TIMESTAMP = sh(script: 'date "+%Y-%m-%d %H:%M:%S"', returnStdout: true).trim()
        GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        VALIDATION_STATUS = 'NOT_STARTED'
    }
    
    triggers {
        githubPush()
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 20, unit: 'MINUTES')
        timestamps()
    }
    
    stages {
        stage('Checkout & Setup') {
            steps {
                script {
                    echo "🔄 Starting build #${BUILD_NUMBER} at ${BUILD_TIMESTAMP}"
                    echo "📍 Git commit: ${GIT_COMMIT_SHORT}"
                    
                    try {
                        checkout scm
                        echo "✅ Code checkout successful"
                        
                        // Check for source files
                        def pythonFiles = sh(script: 'find . -name "*.py" -not -path "./.git/*" | wc -l', returnStdout: true).trim()
                        def htmlFiles = sh(script: 'find . -name "*.html" -not -path "./.git/*" | wc -l', returnStdout: true).trim()
                        def cssFiles = sh(script: 'find . -name "*.css" -not -path "./.git/*" | wc -l', returnStdout: true).trim()
                        def jsFiles = sh(script: 'find . -name "*.js" -not -path "./.git/*" | wc -l', returnStdout: true).trim()
                        def phpFiles = sh(script: 'find . -name "*.php" -not -path "./.git/*" | wc -l', returnStdout: true).trim()
                        
                        def totalFiles = pythonFiles.toInteger() + htmlFiles.toInteger() + cssFiles.toInteger() + jsFiles.toInteger() + phpFiles.toInteger()
                        echo "📊 Found files - Python: ${pythonFiles}, HTML: ${htmlFiles}, CSS: ${cssFiles}, JS: ${jsFiles}, PHP: ${phpFiles}"
                        
                        if (totalFiles == 0) {
                            echo "ℹ️ No source code files found - skipping validation"
                            env.VALIDATION_STATUS = 'SKIPPED'
                        } else {
                            echo "✅ Found ${totalFiles} source files - proceeding with validation"
                            env.VALIDATION_STATUS = 'READY'
                        }
                        
                    } catch (Exception e) {
                        echo "❌ Setup failed: ${e.getMessage()}"
                        currentBuild.result = 'FAILURE'
                        error("Setup stage failed")
                    }
                }
            }
        }
        
        stage('Critical Error Validation') {
            when {
                environment name: 'VALIDATION_STATUS', value: 'READY'
            }
            steps {
                script {
                    echo "🔍 Checking for CRITICAL ERRORS ONLY (syntax errors, missing imports, etc.)"
                    
                    try {
                        sh 'chmod +x validate-critical-errors.sh'
                        def validationResult = sh(
                            script: './validate-critical-errors.sh',
                            returnStatus: true
                        )
                        
                        if (validationResult == 0) {
                            env.VALIDATION_STATUS = 'SUCCESS'
                            echo "✅ No critical errors found - code should run without crashing"
                        } else {
                            env.VALIDATION_STATUS = 'FAILED'
                            echo "❌ CRITICAL ERRORS DETECTED - code will crash!"
                            
                            if (fileExists('critical_errors.txt')) {
                                echo "🚨 Critical Error Report:"
                                sh 'cat critical_errors.txt'
                            }
                            
                            currentBuild.result = 'FAILURE'
                            error("Critical errors found that will cause program crashes")
                        }
                        
                    } catch (Exception e) {
                        env.VALIDATION_STATUS = 'ERROR'
                        echo "💥 Validation failed: ${e.getMessage()}"
                        currentBuild.result = 'FAILURE'
                        error("Validation process failed")
                    }
                }
            }
        }
        
        stage('Build Summary') {
            steps {
                script {
                    echo "📊 BUILD SUMMARY"
                    echo "================"
                    echo "Build: #${BUILD_NUMBER}"
                    echo "Time: ${BUILD_TIMESTAMP}"
                    echo "Commit: ${GIT_COMMIT_SHORT}"
                    echo "Status: ${env.VALIDATION_STATUS}"
                    echo "Result: ${currentBuild.result ?: 'SUCCESS'}"
                    
                    // Show build history
                    echo "\n📈 RECENT BUILD HISTORY:"
                    def builds = []
                    def currentJob = currentBuild
                    for (int i = 0; i < 5 && currentJob != null; i++) {
                        def status = currentJob.result ?: 'SUCCESS'
                        def statusIcon = status == 'SUCCESS' ? '✅' : status == 'FAILURE' ? '❌' : '⚠️'
                        builds.add("#${currentJob.number} - ${statusIcon} ${status}")
                        currentJob = currentJob.previousBuild
                    }
                    builds.each { echo "  ${it}" }
                    echo "================"
                }
            }
        }
        
        stage('Archive Results') {
            steps {
                script {
                    echo "📄 Archiving build results..."
                    
                    // Create build summary
                    writeFile file: 'build-summary.txt', text: """
BUILD SUMMARY REPORT
===================
Build Number: ${BUILD_NUMBER}
Build Time: ${BUILD_TIMESTAMP}  
Git Commit: ${GIT_COMMIT_SHORT}
Validation Status: ${env.VALIDATION_STATUS}
Build Result: ${currentBuild.result ?: 'SUCCESS'}
Duration: ${currentBuild.durationString}
===================
"""
                    
                    // Archive all reports
                    archiveArtifacts artifacts: 'build-summary.txt', allowEmptyArchive: true
                    if (fileExists('critical_errors.txt')) {
                        archiveArtifacts artifacts: 'critical_errors.txt', allowEmptyArchive: true
                    }
                    
                    echo "✅ Results archived successfully"
                }
            }
        }
    }
    
    post {
        success {
            script {
                echo "🎉 BUILD SUCCESSFUL!"
                if (env.VALIDATION_STATUS == 'SKIPPED') {
                    echo "ℹ️ No source files found to validate"
                } else {
                    echo "✅ All critical validations passed - code is safe to run"
                }
            }
        }
        
        failure {
            script {
                echo "💥 BUILD FAILED!"
                if (env.VALIDATION_STATUS == 'FAILED') {
                    echo "🚨 Critical errors found that WILL cause crashes"
                    echo "💡 Fix these errors before deployment:"
                    echo "   - Python: Fix syntax errors, missing imports"
                    echo "   - HTML: Fix unclosed tags, malformed structure"  
                    echo "   - CSS: Fix syntax errors, invalid properties"
                    echo "   - JS: Fix syntax errors, undefined variables"
                    echo "   - PHP: Fix syntax errors, missing semicolons"
                }
            }
        }
        
        cleanup {
            script {
                echo "🧹 Cleaning up..."
                sh 'rm -f *.tmp || true'
                echo "✨ Cleanup completed"
            }
        }
    }
}
