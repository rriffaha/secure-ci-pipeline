pipeline {
    agent any

    tools {
        maven 'M3'
        jdk 'JDK21'
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

        stage('Dependency Scan') {
            steps {
                echo 'Running OWASP Dependency-Check...'
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                    sh '''
                mvn org.owasp:dependency-check-maven:check \
                -Dformats=HTML,XML \
                -DdataDirectory="$WORKSPACE/.dc-data"
            '''
                }
            }
            post {
                always {
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