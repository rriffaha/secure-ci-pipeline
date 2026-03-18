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

        stage('Dependency Scanning') {
            parallel {
                stage('OWASP Scan') {
                    steps {
                        echo 'Running OWASP Dependency-Check...'

                        withCredentials([string(credentialsId: 'NVD_API_KEY', variable: 'NVD_API_KEY')]) {
                            catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                                sh '''
                                    mvn org.owasp:dependency-check-maven:purge || true

                                    mvn -B org.owasp:dependency-check-maven:check \
                                    -DnvdApiKey=$NVD_API_KEY \
                                    -DfailBuildOnCVSS=9 \
                                    -Dformats=HTML,XML \
                                    -DdataDirectory="$WORKSPACE/.dc-data"
                                '''
                            }
                        }

                        script {
                            if (fileExists('target/dependency-check-report.xml') || fileExists('target/dependency-check-report.html')) {
                                stash name: 'dependency-check-reports',
                                        includes: 'target/dependency-check-report.xml,target/dependency-check-report.html',
                                        allowEmpty: true
                            } else {
                                echo 'Dependency-Check reports were not generated, skipping stash.'
                            }
                        }
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

        stage('Trivy File Scan') {
            steps {
                sh '''
                    mkdir -p .trivy-bin
                    if [ ! -f .trivy-bin/trivy ]; then
                      curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b .trivy-bin
                    fi
                    ./.trivy-bin/trivy fs . > trivy-report.txt
                    cat trivy-report.txt
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                echo 'Skipping SonarQube analysis for now, server not reachable'
            }
        }

        stage('Publish Dependency-Check Results') {
            steps {
                echo 'Publishing Dependency-Check reports...'

                script {
                    try {
                        unstash 'dependency-check-reports'
                    } catch (err) {
                        echo 'No stashed dependency-check reports found, skipping unstash.'
                    }
                }

                script {
                    if (fileExists('target/dependency-check-report.xml')) {
                        dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
                    } else {
                        echo 'XML report not found, skipping dependencyCheckPublisher.'
                    }

                    if (fileExists('target/dependency-check-report.html')) {
                        publishHTML(target: [
                                reportDir: 'target',
                                reportFiles: 'dependency-check-report.html',
                                reportName: 'Dependency-Check Report',
                                keepAll: true,
                                alwaysLinkToLastBuild: true,
                                allowMissing: true
                        ])
                    } else {
                        echo 'HTML report not found, skipping HTML publish.'
                    }
                }
            }
        }

        stage('Code Coverage') {
            steps {
                echo 'Generating JaCoCo coverage report...'
                sh 'mvn test jacoco:report'
                publishHTML(target: [
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'target/site/jacoco',
                        reportFiles: 'index.html',
                        reportName: 'Code Coverage HTML Report'
                ])
            }
        }

        stage('Test') {
            steps {
                echo 'Tests already executed during Code Coverage stage'
            }
        }

        stage('Integration Tests') {
            steps {
                echo 'Running integration tests...'

                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                    sh 'mvn clean verify -Pintegration-tests'
                }

                junit testResults: 'target/failsafe-reports/*.xml', allowEmptyResults: true
            }
        }

        stage('Package') {
            steps {
                echo 'Packaging the application...'
                sh 'mvn package -DskipTests'
            }
            post {
                success {
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                }
            }
        }

        stage('Docker Build') {
            steps {
                echo 'Building Docker image...'
                sh 'docker build -t rriffaha/demo:${BUILD_NUMBER} .'
                sh 'docker tag rriffaha/demo:${BUILD_NUMBER} rriffaha/demo:latest'
            }
        }

        stage('Docker Push') {
            steps {
                echo 'Pushing Docker image to DockerHub...'
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push rriffaha/demo:${BUILD_NUMBER}
                        docker push rriffaha/demo:latest
                    '''
                 }
            }
        }
    }
}