pipeline {
    agent any

    environment {
        GITHUB_CREDENTIALS = 'github-pat'
        VALIDATION_STATUS = ''
        BUILD_TIMESTAMP = sh(script: 'date "+%Y-%m-%d %H:%M:%S"', returnStdout: true).trim()
        SMTP_HOST = 'smtp.privateemail.com'
        SMTP_PORT = '587'
        SMTP_USER = 'support@dcodax.com'
        NOTIFICATION_EMAILS = 'kencypher56@gmail.com,rottinken@gmail.com'
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "🔄 Checking out code from GitHub..."
                    checkout scm
                }
            }
        }

        stage('Code Validation') {
            steps {
                script {
                    echo "🔍 Starting code validation..."
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
    }

    post {
        success {
            script {
                emailext (
                    subject: "✅ Jenkins Build SUCCESS - ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """
                    <html>
                    <body>
                    <h2 style="color: green;">🎉 BUILD SUCCESSFUL</h2>
                    <p>All code validation checks passed successfully!</p>
                    <p><a href="${env.BUILD_URL}Code_Validation_Report">View Validation Report</a></p>
                    </body>
                    </html>
                    """,
                    mimeType: 'text/html',
                    to: "${env.NOTIFICATION_EMAILS}",
                    from: "${env.SMTP_USER}"
                )
            }
        }

        failure {
            script {
                emailext (
                    subject: "❌ Jenkins Build FAILED - ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """
                    <html>
                    <body>
                    <h2 style="color: red;">❌ BUILD FAILED</h2>
                    <p>Code validation failed. Please check validation report.</p>
                    <p><a href="${env.BUILD_URL}Code_Validation_Report">View Validation Report</a></p>
                    </body>
                    </html>
                    """,
                    mimeType: 'text/html',
                    to: "${env.NOTIFICATION_EMAILS}",
                    from: "${env.SMTP_USER}"
                )
            }
        }
    }
}
