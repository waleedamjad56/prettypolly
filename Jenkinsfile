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
                    echo "🔍 Checking for source code files..."
                    def htmlFiles = sh(script: 'find . -name "*.html" -not -path "./node_modules/*" -not -path "./.git/*" | wc -l', returnStdout: true).trim()
                    def cssFiles = sh(script: 'find . -name "*.css" -not -path "./node_modules/*" -not -path "./.git/*" | wc -l', returnStdout: true).trim()
                    def jsFiles = sh(script: 'find . -name "*.js" -not -path "./node_modules/*" -not -path "./.git/*" | wc -l', returnStdout: true).trim()
                    def pythonFiles = sh(script: 'find . -name "*.py" -not -path "./node_modules/*" -not -path "./.git/*" | wc -l', returnStdout: true).trim()
                    def phpFiles = sh(script: 'find . -name "*.php" -not -path "./node_modules/*" -not -path "./.git/*" | wc -l', returnStdout: true).trim()
                    echo "📊 Found files - HTML: ${htmlFiles}, CSS: ${cssFiles}, JS: ${jsFiles}, Python: ${pythonFiles}, PHP: ${phpFiles}"
                    if (htmlFiles.toInteger() == 0 && cssFiles.toInteger() == 0 && jsFiles.toInteger() == 0 && pythonFiles.toInteger() == 0 && phpFiles.toInteger() == 0) {
                        echo "⚠️ No source code files found to validate"
                        env.VALIDATION_STATUS = 'SKIPPED'
                    } else {
                        echo "✅ Source code files found, proceeding with validation"
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
                    echo "🔍 Starting code validation..."
                    echo "📋 Checking Python, HTML, CSS, JS, and PHP for critical errors"
                    try {
                        sh 'chmod +x validate-code.sh'
                        def validationResult = sh(script: './validate-code.sh', returnStatus: true)
                        if (validationResult == 0) {
                            env.VALIDATION_STATUS = 'SUCCESS'
                            echo "✅ All validations passed or no critical errors found"
                        } else {
                            env.VALIDATION_STATUS = 'FAILED'
                            echo "❌ Critical errors detected"
                            currentBuild.result = 'FAILURE'
                            error("Critical validation errors detected")
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
                    echo "📊 Build Summary"
                    echo "Build Number: ${BUILD_NUMBER}"
                    echo "Build Time: ${BUILD_TIMESTAMP}"
                    echo "Git Commit: ${GIT_COMMIT_SHORT}"
                    echo "Validation Status: ${env.VALIDATION_STATUS}"
                    echo "Build Result: ${currentBuild.result ?: 'SUCCESS'}"
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🔄 Post-build actions completed"
            }
        }
        success {
            echo "🎉 Build completed successfully"
        }
        failure {
            echo "💥 Build failed due to critical errors"
        }
        cleanup {
            sh 'rm -f *.txt venv/ -r || true'
            echo "🧹 Cleanup completed"
        }
    }
}
