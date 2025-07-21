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
