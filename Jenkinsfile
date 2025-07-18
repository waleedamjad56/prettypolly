pipeline {
    agent any

    environment {
        GITHUB_CREDENTIALS = 'github-pat' // This will be the credential ID we create
        VALIDATION_STATUS = ''
        BUILD_TIMESTAMP = sh(script: 'date "+%Y-%m-%d %H:%M:%S"', returnStdout: true).trim()
    }

    triggers {
        githubPush() // Trigger on GitHub push
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "🔄 Checking out code from GitHub..."
                    // Checkout code from GitHub
                    checkout scm

                    // Display commit information
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
                script {
                    echo "🔍 Starting code validation..."

                    // Make validation script executable
                    sh 'chmod +x validate-code.sh'

                    // Run validation
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
                    // Archive validation report
                    archiveArtifacts artifacts: 'validation_report.txt, validation_status.txt', allowEmptyArchive: true

                    // Publish validation report
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
                script {
                    echo "🚀 Deploying to production..."

                    // Add your deployment logic here
                    // For example, copying files to web server, uploading to S3, etc.

                    // Example deployment steps:
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

                        echo "✅ Deployment package created successfully"
                        echo "=== DEPLOYMENT COMPLETED ==="
                    '''
                }
            }
        }
    }

    post {
        success {
            script {
                // Send success notification
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

                    <hr>
                    <p><em>This is an automated message from Jenkins CI/CD Pipeline</em></p>
                    """,
                    mimeType: 'text/html',
                    to: 'kencypher56@gmail.com,rottinken@gmail.com'
                )
            }
        }

        failure {
            script {
                // Send failure notification
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

                    <hr>
                    <p><em>This is an automated message from Jenkins CI/CD Pipeline</em></p>
                    """,
                    mimeType: 'text/html',
                    to: 'kencypher56@gmail.com,rottinken@gmail.com'
                )
            }
        }

        always {
            // Clean up workspace
            cleanWs()
        }
    }
}
