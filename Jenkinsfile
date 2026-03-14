pipeline {
    agent any

    tools {
        maven 'M3'
        jdk 'JDK17'
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Cloning repository...'
                checkout scm
            }
        }

        stage('Build') {
            steps {
                echo 'Building the Maven project...'
                sh 'mvn clean compile'
            }
        }

        stage('Dependency Scanning') {
            parallel {
                stage('OWASP Scan') {
                    steps {
                        echo 'Running OWASP Dependency-Check...'
                        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                            sh '''
                                mvn -B org.owasp:dependency-check-maven:check \
                                -DfailBuildOnCVSS=9 \
                                -Dformats=HTML,XML \
                                -DdataDirectory="$WORKSPACE/.dc-data"
                            '''
                        }
                        stash name: 'dependency-check-reports', includes: 'target/dependency-check-report.xml,target/dependency-check-report.html'
                    }
                }

                stage('Dependency Updates') {
                    steps {
                        echo 'Checking for dependency updates...'
                        sh 'mvn versions:display-dependency-updates'
                    }
                }
            }
        }

        stage('Publish Dependency-Check Results') {
            steps {
                echo 'Publishing Dependency-Check reports...'
                unstash 'dependency-check-reports'

                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'

                publishHTML(target: [
                        reportDir: 'target',
                        reportFiles: 'dependency-check-report.html',
                        reportName: 'Dependency-Check Report',
                        keepAll: true,
                        alwaysLinkToLastBuild: true,
                        allowMissing: true
                ])
            }
        }

        stage('Test') {
            steps {
                echo 'Running unit tests...'
                sh 'mvn test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('Package') {
            steps {
                echo 'Packaging the application...'
                sh 'mvn package'
            }
            post {
                success {
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                }
            }
        }
    }
}