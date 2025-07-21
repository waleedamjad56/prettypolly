pipeline {
    agent any

    environment {
        GITHUB_CREDENTIALS = 'github-pat'
        VALIDATION_STATUS = ''
        BUILD_TIMESTAMP = sh(script: 'date "+%Y-%m-%d %H:%M:%S"', returnStdout: true).trim()
        // EMAIL SETTINGS NOW COME FROM DOCKER ENVIRONMENT VARIABLES
        // NO HARDCODED EMAILS IN PIPELINE - SECURITY BEST PRACTICE
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
                        currentBuild.result = 'FAILURE'
                        error "Code validation failed. Stopping deployment."
                    }
                }
            }
            post {
                always {
                    script {
                        // Archive artifacts
                        if (fileExists('validation_report.txt')) {
                            archiveArtifacts artifacts: 'validation_report.txt', allowEmptyArchive: true
                        }
                        if (fileExists('validation_status.txt')) {
                            archiveArtifacts artifacts: 'validation_status.txt', allowEmptyArchive: true
                        }
                        
                        // Publish HTML report if validation report exists
                        if (fileExists('validation_report.txt')) {
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
        }
    }

    post {
        always {
            script {
                // Get email settings from environment variables (set in Docker)
                def notificationEmails = System.getenv('NOTIFICATION_EMAILS') ?: 'fallback@example.com'
                def smtpUser = System.getenv('SMTP_USER') ?: 'no-smtp-user'
                
                echo "📧 Preparing email notification..."
                echo "Email recipients: ${notificationEmails}"
                echo "SMTP user: ${smtpUser}"

                // Read validation report for email content
                def validationReport = ""
                if (fileExists('validation_report.txt')) {
                    validationReport = readFile('validation_report.txt')
                } else {
                    validationReport = "No validation report generated"
                }

                // Get build log excerpt
                def buildLog = ""
                try {
                    buildLog = currentBuild.rawBuild.getLog(50).join('\n')
                } catch (Exception e) {
                    buildLog = "Build log not available"
                }

                // Get Git commit info
                def gitCommit = ""
                def gitBranch = ""
                try {
                    gitCommit = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
                    gitBranch = sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
                } catch (Exception e) {
                    gitCommit = "N/A"
                    gitBranch = "N/A"
                }

                // Calculate build duration
                def buildDuration = ""
                if (currentBuild.duration) {
                    def duration = currentBuild.duration
                    def minutes = duration / 60000
                    def seconds = (duration % 60000) / 1000
                    buildDuration = "${minutes}m ${seconds}s"
                } else {
                    buildDuration = "N/A"
                }

                // Determine build status and emoji
                def buildStatus = currentBuild.result ?: 'SUCCESS'
                def statusEmoji = buildStatus == 'SUCCESS' ? '✅' : '❌'
                def statusColor = buildStatus == 'SUCCESS' ? 'green' : 'red'

                // Common email content
                def emailSubject = "${statusEmoji} Jenkins Build ${buildStatus}: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
                def emailBody = """
                <html>
                <body style="font-family: Arial, sans-serif; margin: 20px;">
                    <div style="border: 2px solid ${statusColor}; border-radius: 8px; padding: 20px; background-color: #f9f9f9;">
                        <h2 style="color: ${statusColor}; margin-top: 0;">
                            ${statusEmoji} Build ${buildStatus}
                        </h2>
                        
                        <div style="background-color: white; padding: 15px; border-radius: 5px; margin: 10px 0;">
                            <h3>📋 Build Information</h3>
                            <table style="width: 100%; border-collapse: collapse;">
                                <tr><td style="padding: 5px; font-weight: bold;">Project:</td><td style="padding: 5px;">${env.JOB_NAME}</td></tr>
                                <tr><td style="padding: 5px; font-weight: bold;">Build Number:</td><td style="padding: 5px;">#${env.BUILD_NUMBER}</td></tr>
                                <tr><td style="padding: 5px; font-weight: bold;">Build Status:</td><td style="padding: 5px; color: ${statusColor};">${buildStatus}</td></tr>
                                <tr><td style="padding: 5px; font-weight: bold;">Build Time:</td><td style="padding: 5px;">${env.BUILD_TIMESTAMP}</td></tr>
                                <tr><td style="padding: 5px; font-weight: bold;">Duration:</td><td style="padding: 5px;">${buildDuration}</td></tr>
                                <tr><td style="padding: 5px; font-weight: bold;">Git Branch:</td><td style="padding: 5px;">${gitBranch}</td></tr>
                                <tr><td style="padding: 5px; font-weight: bold;">Git Commit:</td><td style="padding: 5px;">${gitCommit.take(8)}</td></tr>
                                <tr><td style="padding: 5px; font-weight: bold;">SMTP Server:</td><td style="padding: 5px;">smtp.privateemail.com:587</td></tr>
                                <tr><td style="padding: 5px; font-weight: bold;">Email From:</td><td style="padding: 5px;">${smtpUser}</td></tr>
                            </table>
                        </div>

                        <div style="background-color: white; padding: 15px; border-radius: 5px; margin: 10px 0;">
                            <h3>🔍 Code Validation Report</h3>
                            <pre style="background-color: #f4f4f4; padding: 10px; border-radius: 3px; font-size: 12px; overflow-x: auto;">${validationReport}</pre>
                        </div>

                        <div style="background-color: white; padding: 15px; border-radius: 5px; margin: 10px 0;">
                            <h3>📝 Recent Build Log</h3>
                            <pre style="background-color: #f4f4f4; padding: 10px; border-radius: 3px; font-size: 12px; overflow-x: auto;">${buildLog}</pre>
                        </div>

                        <div style="background-color: white; padding: 15px; border-radius: 5px; margin: 10px 0;">
                            <h3>🔗 Quick Links</h3>
                            <p>
                                <a href="${env.BUILD_URL}" style="color: #007cba; text-decoration: none;">📊 View Full Build Details</a><br>
                                <a href="${env.BUILD_URL}console" style="color: #007cba; text-decoration: none;">📋 View Console Output</a><br>
                                <a href="${env.BUILD_URL}artifact/" style="color: #007cba; text-decoration: none;">📁 View Build Artifacts</a>
                            </p>
                        </div>

                        <div style="background-color: #e8f4f8; padding: 10px; border-radius: 5px; margin: 10px 0; font-size: 12px; color: #666;">
                            <p><strong>Jenkins Server:</strong> ${env.JENKINS_URL}</p>
                            <p><strong>Notification sent:</strong> ${new Date().format('yyyy-MM-dd HH:mm:ss')}</p>
                            <p><strong>Recipients:</strong> ${notificationEmails}</p>
                        </div>
                    </div>
                </body>
                </html>
                """

                // Send email notification with improved error handling
                echo "📧 Sending email notification to: ${notificationEmails}"
                try {
                    emailext (
                        subject: emailSubject,
                        body: emailBody,
                        mimeType: 'text/html',
                        to: notificationEmails,
                        from: smtpUser,
                        replyTo: smtpUser,
                        attachLog: true,
                        compressLog: true,
                        attachmentsPattern: 'validation_report.txt,validation_status.txt'
                    )
                    echo "✅ Email notification sent successfully to: ${notificationEmails}!"
                } catch (Exception e) {
                    echo "❌ Failed to send email notification: ${e.getMessage()}"
                    echo "💡 Check SMTP settings and credentials in Docker environment"
                    // Don't fail the build if email fails
                }
            }
        }

        success {
            echo "🎉 Build completed successfully!"
        }

        failure {
            echo "💥 Build failed!"
        }

        cleanup {
            script {
                echo "🧹 Cleaning up workspace..."
                cleanWs()
            }
        }
    }
}
