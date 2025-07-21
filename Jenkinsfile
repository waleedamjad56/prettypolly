pipeline {
    agent any
    
    environment {
        BUILD_TIMESTAMP = sh(script: 'date "+%Y-%m-%d %H:%M:%S"', returnStdout: true).trim()
        VALIDATION_STATUS = ''
        GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD 2>/dev/null || echo "unknown"', returnStdout: true).trim()
        PATH = "$PATH:/root/.local/bin"
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
                    echo "🏗️ Build #${BUILD_NUMBER} started at ${BUILD_TIMESTAMP}"
                    
                    try {
                        // Checkout code
                        checkout scm
                        echo "✅ Code checkout successful"
                        echo "📍 Git commit: ${GIT_COMMIT_SHORT}"
                        
                        // List repository contents
                        sh '''
                            echo "📂 Repository contents:"
                            ls -la
                            echo ""
                            echo "🔍 Searching for code files..."
                            find . -type f \\( -name "*.py" -o -name "*.html" -o -name "*.css" -o -name "*.js" -o -name "*.php" \\) -not -path "./node_modules/*" -not -path "./.git/*" | head -10
                        '''
                        
                    } catch (Exception e) {
                        echo "❌ Checkout failed: ${e.getMessage()}"
                        currentBuild.result = 'FAILURE'
                        error("Repository checkout failed")
                    }
                }
            }
        }
        
        stage('Environment Setup') {
            steps {
                script {
                    echo "🔧 Setting up validation environment..."
                    
                    try {
                        // Check tool availability
                        sh '''
                            echo "🔍 Checking tool availability:"
                            echo -n "Python 3: "; python3 --version || echo "Not available"
                            echo -n "Python 3.10: "; python3.10 --version || echo "Not available"
                            echo -n "Node.js: "; node --version || echo "Not available"
                            echo -n "PHP: "; php --version | head -1 || echo "Not available"
                            echo -n "flake8: "; flake8 --version || echo "Not available"
                            echo -n "eslint: "; eslint --version || echo "Not available"
                            echo -n "htmlhint: "; htmlhint --version || echo "Not available"
                            echo -n "csslint: "; csslint --version || echo "Not available"
                        '''
                        
                        // Make validation script executable
                        sh 'chmod +x validate-code.sh'
                        echo "✅ Environment setup completed"
                        
                    } catch (Exception e) {
                        echo "⚠️ Environment setup warning: ${e.getMessage()}"
                        // Don't fail the build for environment setup issues
                    }
                }
            }
        }
        
        stage('Pre-Validation Check') {
            steps {
                script {
                    echo "🔍 Analyzing codebase for validation..."
                    
                    try {
                        def fileStats = sh(script: '''
                            echo "FILE_STATS:"
                            echo -n "HTML: "; find . -name "*.html" -not -path "./node_modules/*" -not -path "./.git/*" | wc -l
                            echo -n "CSS: "; find . -name "*.css" -not -path "./node_modules/*" -not -path "./.git/*" | wc -l  
                            echo -n "JS: "; find . -name "*.js" -not -path "./node_modules/*" -not -path "./.git/*" | wc -l
                            echo -n "Python: "; find . -name "*.py" -not -path "./node_modules/*" -not -path "./.git/*" | wc -l
                            echo -n "PHP: "; find . -name "*.php" -not -path "./node_modules/*" -not -path "./.git/*" | wc -l
                        ''', returnStdout: true).trim()
                        
                        echo "📊 Code file statistics:"
                        echo fileStats
                        
                        // Check if we have any files to validate
                        def totalFiles = sh(script: '''
                            find . -type f \\( -name "*.py" -o -name "*.html" -o -name "*.css" -o -name "*.js" -o -name "*.php" \\) -not -path "./node_modules/*" -not -path "./.git/*" | wc -l
                        ''', returnStdout: true).trim().toInteger()
                        
                        if (totalFiles == 0) {
                            echo "⚠️ No source code files found to validate"
                            env.VALIDATION_STATUS = 'SKIPPED'
                        } else {
                            echo "✅ Found ${totalFiles} source code files, proceeding with validation"
                        }
                        
                    } catch (Exception e) {
                        echo "⚠️ Pre-validation check warning: ${e.getMessage()}"
                        // Don't fail for pre-validation issues
                    }
                }
            }
        }
        
        stage('Critical Code Validation') {
            when {
                not { environment name: 'VALIDATION_STATUS', value: 'SKIPPED' }
            }
            steps {
                script {
                    echo "🔍 Starting critical code validation..."
                    echo "📋 Checking Python, HTML, CSS, JavaScript, and PHP for critical errors"
                    echo "⚠️ Minor issues and warnings will not fail the build"
                    
                    try {
                        // Run the validation script
                        def validationResult = sh(script: './validate-code.sh', returnStatus: true)
                        
                        // Always try to show the validation report
                        try {
                            def validationReport = readFile('validation_report.txt')
                            echo "📊 Validation Report Generated:"
                            echo validationReport
                        } catch (Exception reportError) {
                            echo "⚠️ Could not read validation report: ${reportError.getMessage()}"
                        }
                        
                        if (validationResult == 0) {
                            env.VALIDATION_STATUS = 'SUCCESS'
                            echo "✅ All critical validations passed!"
                            echo "🚀 Code is ready for deployment"
                        } else {
                            env.VALIDATION_STATUS = 'FAILED'
                            echo "❌ Critical errors detected that prevent code execution"
                            currentBuild.result = 'FAILURE'
                            error("Critical validation errors must be fixed before deployment")
                        }
                        
                    } catch (Exception e) {
                        env.VALIDATION_STATUS = 'ERROR'
                        echo "💥 Validation process failed: ${e.getMessage()}"
                        currentBuild.result = 'FAILURE'
                        error("Validation process encountered an error")
                    }
                }
            }
        }
        
        stage('Build Summary') {
            steps {
                script {
                    echo "📊 === BUILD SUMMARY ==="
                    echo "🏗️ Build Number: ${BUILD_NUMBER}"
                    echo "⏰ Build Time: ${BUILD_TIMESTAMP}"
                    echo "📍 Git Commit: ${GIT_COMMIT_SHORT}"
                    echo "🔍 Validation Status: ${env.VALIDATION_STATUS}"
                    echo "📈 Build Result: ${currentBuild.result ?: 'SUCCESS'}"
                    echo "========================"
                    
                    // Archive validation artifacts if they exist
                    archiveArtifacts artifacts: 'validation_report.txt, validation_status.txt', allowEmptyArchive: true, fingerprint: true
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🔄 Running post-build cleanup..."
                
                // Clean up temporary files
                sh '''
                    rm -f *.txt *.tmp
                    rm -rf venv/ node_modules/ .eslintrc.critical
                    echo "🧹 Cleanup completed"
                '''
            }
        }
        
        success {
            echo "🎉 BUILD COMPLETED SUCCESSFULLY!"
            echo "✅ No critical errors found - code is deployment ready"
            echo "📦 Validation artifacts archived for review"
        }
        
        failure {
            echo "💥 BUILD FAILED!"
            echo "❌ Critical errors detected that prevent deployment"
            echo "🔧 Please fix the issues and retry the build"
            echo "📋 Check the validation report for specific error details"
        }
        
        unstable {
            echo "⚠️ BUILD UNSTABLE"
            echo "🔍 Some issues detected but build was allowed to continue"
        }
    }
}
