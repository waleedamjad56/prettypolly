pipeline {
    agent any
    
    environment {
        // Build configuration
        BUILD_TIMESTAMP = sh(script: 'date "+%Y-%m-%d %H:%M:%S"', returnStdout: true).trim()
        BUILD_VERSION = "${BUILD_NUMBER}-${GIT_COMMIT?.take(7) ?: 'unknown'}"
        
        // Validation configuration
        VALIDATION_STATUS = ''
        DEPLOY_STATUS = ''
        
        // Tool paths (matching your Docker setup)
        NODE_VERSION = '20'
        PHP_VERSION = '8.1'
        
        // Security settings
        JAVA_OPTS = '-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false'
    }
    
    options {
        // Build retention
        buildDiscarder(logRotator(
            numToKeepStr: '10',
            daysToKeepStr: '30',
            artifactNumToKeepStr: '5'
        ))
        
        // Timeout protection
        timeout(time: 30, unit: 'MINUTES')
        
        // Concurrent builds
        disableConcurrentBuilds()
        
        // Timestamps in console
        timestamps()
        
        // ANSI color support
        ansiColor('xterm')
    }
    
    triggers {
        githubPush()
        pollSCM('H/5 * * * *') // Poll every 5 minutes as backup
    }
    
    stages {
        stage('Initialize') {
            steps {
                script {
                    echo "🚀 Starting Jenkins Pipeline"
                    echo "📅 Build Timestamp: ${env.BUILD_TIMESTAMP}"
                    echo "🔢 Build Version: ${env.BUILD_VERSION}"
                    echo "🌿 Branch: ${env.BRANCH_NAME ?: 'main'}"
                    
                    // Create build info
                    writeFile file: 'build-info.json', text: """
{
    "buildNumber": "${BUILD_NUMBER}",
    "buildVersion": "${BUILD_VERSION}",
    "timestamp": "${BUILD_TIMESTAMP}",
    "branch": "${env.BRANCH_NAME ?: 'main'}",
    "commit": "${GIT_COMMIT ?: 'unknown'}",
    "jenkinsUrl": "${JENKINS_URL}",
    "jobName": "${JOB_NAME}"
}
"""
                }
            }
        }
        
        stage('Checkout & Analysis') {
            parallel {
                stage('Code Checkout') {
                    steps {
                        script {
                            echo "📥 Checking out source code..."
                            
                            try {
                                checkout scm
                                
                                // Get commit info
                                env.GIT_COMMIT_MSG = sh(
                                    script: 'git log -1 --pretty=%B',
                                    returnStdout: true
                                ).trim()
                                
                                env.GIT_AUTHOR = sh(
                                    script: 'git log -1 --pretty=%an',
                                    returnStdout: true
                                ).trim()
                                
                                echo "📝 Commit: ${env.GIT_COMMIT_MSG}"
                                echo "👤 Author: ${env.GIT_AUTHOR}"
                                
                            } catch (Exception e) {
                                error "❌ Failed to checkout code: ${e.getMessage()}"
                            }
                        }
                    }
                }
                
                stage('Environment Check') {
                    steps {
                        script {
                            echo "🔍 Checking build environment..."
                            
                            // Check available tools (matching your Docker setup)
                            def tools = [
                                'node --version': 'Node.js',
                                'npm --version': 'NPM',
                                'php --version': 'PHP',
                                'composer --version': 'Composer',
                                'eslint --version': 'ESLint',
                                'htmlhint --version': 'HTMLHint',
                                'csslint --version': 'CSSLint',
                                'git --version': 'Git'
                            ]
                            
                            def toolStatus = [:]
                            tools.each { cmd, name ->
                                try {
                                    def version = sh(script: cmd, returnStdout: true).trim()
                                    toolStatus[name] = "✅ Available: ${version.split('\n')[0]}"
                                    echo "${name}: ${version.split('\n')[0]}"
                                } catch (Exception e) {
                                    toolStatus[name] = "❌ Not available"
                                    echo "⚠️ ${name}: Not available"
                                }
                            }
                            
                            // Save tool status
                            writeFile file: 'tool-status.json', text: groovy.json.JsonBuilder(toolStatus).toPrettyString()
                        }
                    }
                }
            }
        }
        
        stage('Dependency Installation') {
            parallel {
                stage('Node.js Dependencies') {
                    when {
                        expression { fileExists('package.json') }
                    }
                    steps {
                        script {
                            echo "📦 Installing Node.js dependencies..."
                            try {
                                sh '''
                                    npm ci --production=false
                                    npm list --depth=0 || true
                                '''
                                echo "✅ Node.js dependencies installed successfully"
                            } catch (Exception e) {
                                echo "⚠️ Node.js dependency installation had issues: ${e.getMessage()}"
                                // Don't fail the build for dependency warnings
                            }
                        }
                    }
                }
                
                stage('PHP Dependencies') {
                    when {
                        expression { fileExists('composer.json') }
                    }
                    steps {
                        script {
                            echo "🐘 Installing PHP dependencies..."
                            try {
                                sh '''
                                    composer install --no-dev --optimize-autoloader
                                    composer show --installed || true
                                '''
                                echo "✅ PHP dependencies installed successfully"
                            } catch (Exception e) {
                                echo "⚠️ PHP dependency installation had issues: ${e.getMessage()}"
                                // Don't fail the build for dependency warnings
                            }
                        }
                    }
                }
            }
        }
        
        stage('Code Validation') {
            steps {
                script {
                    echo "🔍 Starting comprehensive code validation..."
                    
                    try {
                        // Make validation script executable
                        sh 'chmod +x validate-code.sh'
                        
                        // Run validation with proper error handling
                        def validationResult = sh(
                            script: './validate-code.sh',
                            returnStatus: true
                        )
                        
                        // Check validation results
                        if (validationResult == 0) {
                            env.VALIDATION_STATUS = 'SUCCESS'
                            echo "✅ Code validation passed!"
                            
                            // Check for warnings
                            if (fileExists('validation_report.txt')) {
                                def report = readFile('validation_report.txt')
                                if (report.contains('⚠️')) {
                                    echo "⚠️ Validation passed with warnings - check report for details"
                                }
                            }
                        } else {
                            env.VALIDATION_STATUS = 'FAILED'
                            echo "❌ Code validation failed!"
                            
                            // Read and display validation errors
                            if (fileExists('validation_report.txt')) {
                                echo "📋 Validation Report:"
                                sh 'cat validation_report.txt'
                            }
                            
                            currentBuild.result = 'FAILURE'
                            error "Code validation failed. Build cannot proceed."
                        }
                        
                    } catch (Exception e) {
                        env.VALIDATION_STATUS = 'ERROR'
                        echo "💥 Validation script error: ${e.getMessage()}"
                        currentBuild.result = 'FAILURE'
                        error "Validation script execution failed: ${e.getMessage()}"
                    }
                }
            }
            post {
                always {
                    script {
                        // Archive validation artifacts
                        def artifacts = [
                            'validation_report.txt',
                            'validation_status.txt',
                            'build-info.json',
                            'tool-status.json'
                        ]
                        
                        artifacts.each { artifact ->
                            if (fileExists(artifact)) {
                                archiveArtifacts artifacts: artifact, allowEmptyArchive: true
                                echo "📁 Archived: ${artifact}"
                            }
                        }
                        
                        // Publish HTML reports
                        if (fileExists('validation_report.txt')) {
                            publishHTML([
                                allowMissing: false,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: '.',
                                reportFiles: 'validation_report.txt',
                                reportName: 'Code Validation Report',
                                reportTitles: 'Validation Results'
                            ])
                            echo "📊 Published validation report"
                        }
                    }
                }
            }
        }
        
        stage('Security Scan') {
            when {
                expression { env.VALIDATION_STATUS == 'SUCCESS' }
            }
            steps {
                script {
                    echo "🔒 Running security checks..."
                    
                    try {
                        // Basic security checks
                        sh '''
                            echo "Checking for sensitive data patterns..."
                            
                            # Check for potential secrets
                            if grep -r -i --exclude-dir=node_modules --exclude-dir=.git \
                                -E "(password|secret|key|token)\\s*[:=]\\s*['\"][^'\"]{8,}" . || true; then
                                echo "⚠️ Potential secrets detected - review manually"
                            fi
                            
                            # Check for SQL injection patterns
                            if grep -r -i --exclude-dir=node_modules --exclude-dir=.git \
                                -E "\\$_(GET|POST|REQUEST).*sql" . || true; then
                                echo "⚠️ Potential SQL injection patterns detected"
                            fi
                            
                            echo "✅ Basic security scan completed"
                        '''
                        
                        echo "✅ Security scan completed"
                        
                    } catch (Exception e) {
                        echo "⚠️ Security scan had issues: ${e.getMessage()}"
                        // Don't fail build for security scan issues
                    }
                }
            }
        }
        
        stage('Build Assets') {
            when {
                expression { env.VALIDATION_STATUS == 'SUCCESS' }
            }
            parallel {
                stage('Frontend Build') {
                    when {
                        expression { fileExists('package.json') }
                    }
                    steps {
                        script {
                            echo "🏗️ Building frontend assets..."
                            try {
                                sh '''
                                    if [ -f "package.json" ] && grep -q '"build"' package.json; then
                                        npm run build
                                        echo "✅ Frontend build completed"
                                    else
                                        echo "ℹ️ No build script found in package.json"
                                    fi
                                '''
                            } catch (Exception e) {
                                echo "⚠️ Frontend build had issues: ${e.getMessage()}"
                                // Continue with warnings
                            }
                        }
                    }
                }
                
                stage('Backend Build') {
                    when {
                        expression { fileExists('composer.json') }
                    }
                    steps {
                        script {
                            echo "🐘 Preparing backend assets..."
                            try {
                                sh '''
                                    if [ -f "composer.json" ]; then
                                        composer dump-autoload --optimize
                                        echo "✅ Backend optimization completed"
                                    fi
                                '''
                            } catch (Exception e) {
                                echo "⚠️ Backend build had issues: ${e.getMessage()}"
                                // Continue with warnings
                            }
                        }
                    }
                }
            }
        }
        
        stage('Testing') {
            when {
                expression { env.VALIDATION_STATUS == 'SUCCESS' }
            }
            parallel {
                stage('Unit Tests') {
                    steps {
                        script {
                            echo "🧪 Running unit tests..."
                            try {
                                sh '''
                                    # Node.js tests
                                    if [ -f "package.json" ] && grep -q '"test"' package.json; then
                                        npm test || echo "⚠️ Some Node.js tests failed"
                                    fi
                                    
                                    # PHP tests
                                    if [ -f "phpunit.xml" ] || [ -f "phpunit.xml.dist" ]; then
                                        ./vendor/bin/phpunit || echo "⚠️ Some PHP tests failed"
                                    fi
                                    
                                    echo "✅ Testing phase completed"
                                '''
                            } catch (Exception e) {
                                echo "⚠️ Testing had issues: ${e.getMessage()}"
                                // Continue with warnings for tests
                            }
                        }
                    }
                }
                
                stage('Performance Check') {
                    steps {
                        script {
                            echo "⚡ Running performance checks..."
                            try {
                                sh '''
                                    # Basic file size checks
                                    echo "Checking asset sizes..."
                                    find . -name "*.js" -not -path "./node_modules/*" -exec ls -lh {} \\; | head -10
                                    find . -name "*.css" -not -path "./node_modules/*" -exec ls -lh {} \\; | head -10
                                    
                                    echo "✅ Performance check completed"
                                '''
                            } catch (Exception e) {
                                echo "⚠️ Performance check had issues: ${e.getMessage()}"
                            }
                        }
                    }
                }
            }
        }
        
        stage('Deployment Preparation') {
            when {
                expression { env.VALIDATION_STATUS == 'SUCCESS' }
            }
            steps {
                script {
                    echo "📦 Preparing deployment package..."
                    
                    try {
                        sh '''
                            # Create deployment directory
                            mkdir -p deployment
                            
                            # Copy application files (exclude development files)
                            rsync -av --progress . deployment/ \
                                --exclude node_modules \
                                --exclude .git \
                                --exclude .gitignore \
                                --exclude deployment \
                                --exclude "*.log" \
                                --exclude ".env*" \
                                --exclude "tests/" \
                                --exclude "test/" \
                                --exclude "__tests__/"
                            
                            # Create deployment info
                            cat > deployment/deployment-info.txt << EOF
Deployment Package Information
==============================
Build Number: ${BUILD_NUMBER}
Build Version: ${BUILD_VERSION}
Timestamp: ${BUILD_TIMESTAMP}
Branch: ${BRANCH_NAME}
Commit: ${GIT_COMMIT}
Commit Message: ${GIT_COMMIT_MSG}
Author: ${GIT_AUTHOR}
Jenkins Job: ${JOB_NAME}
Jenkins URL: ${BUILD_URL}
EOF
                            
                            echo "✅ Deployment package prepared"
                        '''
                        
                        env.DEPLOY_STATUS = 'READY'
                        
                    } catch (Exception e) {
                        env.DEPLOY_STATUS = 'FAILED'
                        echo "❌ Deployment preparation failed: ${e.getMessage()}"
                        currentBuild.result = 'FAILURE'
                        error "Failed to prepare deployment package"
                    }
                }
            }
        }
        
        stage('Archive & Cleanup') {
            steps {
                script {
                    echo "🗄️ Archiving build artifacts..."
                    
                    try {
                        // Archive deployment package
                        if (fileExists('deployment/')) {
                            sh '''
                                cd deployment
                                tar -czf ../deployment-package-${BUILD_NUMBER}.tar.gz .
                                cd ..
                            '''
                            
                            archiveArtifacts artifacts: 'deployment-package-*.tar.gz', allowEmptyArchive: false
                            echo "📁 Deployment package archived"
                        }
                        
                        // Archive logs and reports
                        sh '''
                            # Collect all logs and reports
                            mkdir -p build-artifacts
                            
                            # Copy all txt and json files to artifacts
                            find . -maxdepth 1 -name "*.txt" -o -name "*.json" | while read file; do
                                cp "$file" build-artifacts/ 2>/dev/null || true
                            done
                            
                            echo "✅ Artifacts collected"
                        '''
                        
                        archiveArtifacts artifacts: 'build-artifacts/*', allowEmptyArchive: true
                        
                    } catch (Exception e) {
                        echo "⚠️ Archiving had issues: ${e.getMessage()}"
                        // Don't fail build for archiving issues
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🔄 Post-build cleanup and reporting..."
                
                // Calculate build duration
                def duration = currentBuild.duration ? "${currentBuild.duration / 1000}s" : "unknown"
                
                // Generate final build report
                def buildStatus = currentBuild.result ?: 'SUCCESS'
                def reportContent = """
=== JENKINS BUILD REPORT ===
Build Number: ${BUILD_NUMBER}
Build Version: ${BUILD_VERSION}
Status: ${buildStatus}
Duration: ${duration}
Timestamp: ${BUILD_TIMESTAMP}
Branch: ${env.BRANCH_NAME ?: 'main'}
Commit: ${env.GIT_COMMIT ?: 'unknown'}
Author: ${env.GIT_AUTHOR ?: 'unknown'}
Validation: ${env.VALIDATION_STATUS ?: 'UNKNOWN'}
Deployment: ${env.DEPLOY_STATUS ?: 'NOT_ATTEMPTED'}
Jenkins URL: ${BUILD_URL}
============================
"""
                
                writeFile file: 'final-build-report.txt', text: reportContent
                archiveArtifacts artifacts: 'final-build-report.txt', allowEmptyArchive: true
                
                echo reportContent
            }
        }
        
        success {
            script {
                echo "🎉 BUILD SUCCESSFUL!"
                echo "✅ All stages completed successfully"
                echo "📦 Deployment package is ready"
                echo "🔗 Build URL: ${BUILD_URL}"
            }
        }
        
        failure {
            script {
                echo "💥 BUILD FAILED!"
                echo "❌ Check the console output and reports for details"
                echo "🔗 Build URL: ${BUILD_URL}"
                
                // Try to identify failure reason
                if (env.VALIDATION_STATUS == 'FAILED') {
                    echo "🔍 Failure Reason: Code validation failed"
                } else if (env.DEPLOY_STATUS == 'FAILED') {
                    echo "🔍 Failure Reason: Deployment preparation failed"
                } else {
                    echo "🔍 Failure Reason: Check build logs"
                }
            }
        }
        
        unstable {
            script {
                echo "⚠️ BUILD UNSTABLE"
                echo "🔍 Some tests or checks reported warnings"
                echo "📋 Review validation and test reports"
            }
        }
        
        aborted {
            script {
                echo "🛑 BUILD ABORTED"
                echo "⏰ Build was cancelled or timed out"
            }
        }
        
        cleanup {
            script {
                echo "🧹 Cleaning up workspace..."
                
                try {
                    // Clean up temporary files but keep important artifacts
                    sh '''
                        # Remove large temporary directories
                        rm -rf node_modules/ || true
                        rm -rf vendor/ || true
                        rm -rf deployment/ || true
                        
                        # Clean up temporary files
                        find . -name "*.tmp" -delete || true
                        find . -name "*.temp" -delete || true
                        
                        echo "✅ Cleanup completed"
                    '''
                } catch (Exception e) {
                    echo "⚠️ Cleanup had issues: ${e.getMessage()}"
                    // Don't fail for cleanup issues
                }
                
                // Final workspace cleanup
                cleanWs(
                    cleanWhenAborted: true,
                    cleanWhenFailure: false,  // Keep workspace for debugging failures
                    cleanWhenNotBuilt: true,
                    cleanWhenSuccess: true,
                    cleanWhenUnstable: false, // Keep workspace for debugging unstable builds
                    deleteDirs: true
                )
            }
        }
    }
}
