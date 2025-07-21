pipeline {
    agent any
    
    environment {
        BUILD_TIMESTAMP = sh(script: 'date "+%Y-%m-%d %H:%M:%S"', returnStdout: true).trim()
        VALIDATION_STATUS = ''
        BUILD_STATUS = 'SUCCESS'
    }
    
    triggers {
        githubPush()
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "🔄 Checking out code from repository..."
                    try {
                        checkout scm
                        echo "✅ Code checkout completed successfully"
                    } catch (Exception e) {
                        echo "❌ Failed to checkout code: ${e.getMessage()}"
                        currentBuild.result = 'FAILURE'
                        error("Checkout failed")
                    }
                }
            }
        }
        
        stage('Environment Check') {
            steps {
                script {
                    echo "🔧 Checking validation tools availability..."
                    
                    def tools = [
                        'htmlhint': 'HTML validation',
                        'eslint': 'JavaScript validation', 
                        'csslint': 'CSS validation',
                        'tidy': 'HTML syntax checking'
                    ]
                    
                    tools.each { tool, description ->
                        def toolAvailable = sh(script: "command -v ${tool}", returnStatus: true) == 0
                        if (toolAvailable) {
                            echo "✅ ${description} tool (${tool}) is available"
                        } else {
                            echo "⚠️ ${description} tool (${tool}) not found - validation will be skipped"
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
                        
                        // Run validation and capture result
                        def validationResult = sh(script: './validate-code.sh', returnStatus: true)
                        
                        if (validationResult == 0) {
                            env.VALIDATION_STATUS = 'SUCCESS'
                            env.BUILD_STATUS = 'SUCCESS'
                            echo "✅ Code validation passed - No critical errors found!"
                        } else {
                            env.VALIDATION_STATUS = 'FAILED'
                            env.BUILD_STATUS = 'FAILED'
                            echo "❌ Code validation failed - Critical errors detected!"
                            
                            // Display validation report if available
                            if (fileExists('validation_report.txt')) {
                                echo "📄 Validation Report:"
                                sh 'cat validation_report.txt'
                            }
                            
                            currentBuild.result = 'FAILURE'
                            error("Critical validation errors found - Build stopped to prevent broken deployment")
                        }
                        
                    } catch (Exception e) {
                        env.VALIDATION_STATUS = 'ERROR'
                        env.BUILD_STATUS = 'ERROR'
                        echo "💥 Validation process encountered an error: ${e.getMessage()}"
                        currentBuild.result = 'FAILURE'
                        error("Validation process failed")
                    }
                }
            }
            post {
                always {
                    script {
                        echo "📋 Archiving validation artifacts..."
                        
                        // Archive validation reports
                        if (fileExists('validation_report.txt')) {
                            archiveArtifacts artifacts: 'validation_report.txt', 
                                           allowEmptyArchive: true,
                                           fingerprint: true
                            echo "✅ Validation report archived"
                        }
                        
                        if (fileExists('validation_status.txt')) {
                            archiveArtifacts artifacts: 'validation_status.txt', 
                                           allowEmptyArchive: true,
                                           fingerprint: true
                        }
                        
                        // Publish HTML report using existing htmlpublisher plugin
                        if (fileExists('validation_report.txt')) {
                            try {
                                publishHTML([
                                    allowMissing: false,
                                    alwaysLinkToLastBuild: true,
                                    keepAll: true,
                                    reportDir: '.',
                                    reportFiles: 'validation_report.txt',
                                    reportName: 'Code Validation Report',
                                    reportTitles: 'Validation Results'
                                ])
                                echo "✅ HTML validation report published"
                            } catch (Exception e) {
                                echo "⚠️ Could not publish HTML report: ${e.getMessage()}"
                            }
                        }
                    }
                }
            }
        }
        
        stage('Build Summary') {
            when {
                expression { env.VALIDATION_STATUS == 'SUCCESS' }
            }
            steps {
                script {
                    echo "📊 Build Summary:"
                    echo "   Build Number: ${env.BUILD_NUMBER}"
                    echo "   Build Timestamp: ${env.BUILD_TIMESTAMP}"
                    echo "   Validation Status: ${env.VALIDATION_STATUS}"
                    echo "   Git Commit: ${sh(script: 'git rev-parse --short HEAD 2>/dev/null || echo "N/A"', returnStdout: true).trim()}"
                    
                    // Count files validated
                    def htmlFiles = sh(script: 'find . -name "*.html" -not -path "./node_modules/*" | wc -l', returnStdout: true).trim()
                    def cssFiles = sh(script: 'find . -name "*.css" -not -path "./node_modules/*" | wc -l', returnStdout: true).trim()
                    def jsFiles = sh(script: 'find . -name "*.js" -not -path "./node_modules/*" | wc -l', returnStdout: true).trim()
                    
                    echo "   Files Validated:"
                    echo "     - HTML files: ${htmlFiles}"
                    echo "     - CSS files: ${cssFiles}"
                    echo "     - JavaScript files: ${jsFiles}"
                    
                    if (fileExists('validation_report.txt')) {
                        def reportSize = sh(script: 'wc -l < validation_report.txt', returnStdout: true).trim()
                        echo "   Validation report: ${reportSize} lines generated"
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🔄 Post-build cleanup and reporting..."
                
                // Generate build metadata
                def buildMetadata = [
                    buildNumber: env.BUILD_NUMBER,
                    buildTimestamp: env.BUILD_TIMESTAMP,
                    validationStatus: env.VALIDATION_STATUS ?: 'UNKNOWN',
                    buildStatus: env.BUILD_STATUS ?: 'UNKNOWN',
                    gitCommit: sh(script: 'git rev-parse HEAD 2>/dev/null || echo "N/A"', returnStdout: true).trim(),
                    jenkinsUrl: env.JENKINS_URL ?: 'http://172.86.108.103:9000'
                ]
                
                writeJSON file: 'build_metadata.json', json: buildMetadata
                archiveArtifacts artifacts: 'build_metadata.json', allowEmptyArchive: true
            }
        }
        
        success {
            script {
                echo "🎉 BUILD SUCCESSFUL!"
                echo "   ✅ All validations passed"
                echo "   ✅ Code is ready for deployment"
                echo "   📊 Check validation report for details"
                
                // Set build description
                currentBuild.description = "✅ Validation Passed - Build ${env.BUILD_NUMBER}"
            }
        }
        
        failure {
            script {
                echo "💥 BUILD FAILED!"
                echo "   ❌ Critical validation errors detected"
                echo "   🔍 Check validation report for specific issues"
                echo "   🛠️ Fix errors before retrying deployment"
                
                // Set build description
                currentBuild.description = "❌ Validation Failed - Build ${env.BUILD_NUMBER}"
                
                // Display quick error summary if available
                if (fileExists('validation_report.txt')) {
                    echo "📄 Quick Error Summary:"
                    sh 'grep "❌" validation_report.txt | head -5 || echo "No specific error markers found"'
                }
            }
        }
        
        unstable {
            script {
                echo "⚠️ BUILD UNSTABLE!"
                echo "   🔍 Some issues detected but build continues"
                currentBuild.description = "⚠️ Unstable - Build ${env.BUILD_NUMBER}"
            }
        }
        
        aborted {
            script {
                echo "🛑 BUILD ABORTED!"
                echo "   ℹ️ Build was manually stopped or timed out"
                currentBuild.description = "🛑 Aborted - Build ${env.BUILD_NUMBER}"
            }
        }
        
        cleanup {
            script {
                echo "🧹 Performing workspace cleanup..."
                
                try {
                    // Clean temporary files but keep important artifacts
                    sh '''
                        rm -f *.tmp
                        rm -f *_errors.txt
                        rm -f .eslintrc.tmp
                        rm -f inline_*.tmp
                    '''
                    
                    echo "✅ Cleanup completed successfully"
                    
                    // Don't clean entire workspace to preserve artifacts
                    // cleanWs() - Removed to keep validation reports accessible
                    
                } catch (Exception e) {
                    echo "⚠️ Cleanup encountered issues: ${e.getMessage()}"
                }
            }
        }
    }
}
