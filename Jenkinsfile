pipeline {
    agent any

    environment {
        SONAR_TOKEN = credentials('sonarqube-token')
        ANSIBLE_HOST_KEY_CHECKING = 'False'
    }

    triggers {
        pollSCM('H/5 * * * *')
    }

    tools {
        maven 'Maven'
        jdk 'JDK17'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh './mvnw clean package -DskipTests'
            }
        }

        stage('Unit Tests') {
            steps {
                sh './mvnw test -Pskip-db-tests'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        ./mvnw sonar:sonar \
                        -Dsonar.projectKey=spring-petclinic \
                        -Dsonar.host.url=http://sonarqube:9000 \
                        -Dsonar.login=${SONAR_TOKEN}
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // stage('DAST - Burp Suite Scan') {
        //     steps {
        //         sh '''
        //             # Start app temporarily for scanning
        //             java -jar target/*.jar &
        //             APP_PID=$!
        //             sleep 30

        //             # Run Burp Suite headless scan via REST API (community workaround)
        //             # Or use OWASP ZAP as an alternative for headless DAST
        //             docker run --rm --network devsecops-net \
        //                 -v ${WORKSPACE}/burp-reports:/zap/wrk \
        //                 owasp/zap2docker-stable zap-baseline.py \
        //                 -t http://jenkins:8080 \
        //                 -r burp-report.html || true

        //             kill $APP_PID || true
        //         '''
        //     }
        //     post {
        //         always {
        //             publishHTML(target: [
        //                 allowMissing: true,
        //                 alwaysLinkToLastBuild: true,
        //                 keepAll: true,
        //                 reportDir: 'burp-reports',
        //                 reportFiles: 'burp-report.html',
        //                 reportName: 'DAST Security Report'
        //             ])
        //         }
        //     }
        // }

        stage('DAST - OWASP ZAP') {
            steps {
                sh 'mkdir -p ${WORKSPACE}/zap-reports'
                sh '''
                    # Start the app temporarily for scanning
                    java -jar target/*.jar --server.port=9966 &
                    APP_PID=$!
        
                    # Wait for it to be ready
                    echo "Waiting for app to start..."
                    for i in $(seq 1 20); do
                        curl -s http://localhost:9966/actuator/health && break
                        sleep 5
                    done
        
                    # Run ZAP baseline scan
                    # Uses host network so ZAP can reach localhost:9966
                    docker run --rm \
                        --network host \
                        -v ${WORKSPACE}/zap-reports:/zap/wrk:rw \
                        ghcr.io/zaproxy/zaproxy:stable \
                        zap-baseline.py \
                        -t http://localhost:9966 \
                        -r zap_report.html \
                        -I
        
                    kill $APP_PID || true
                '''
            }
            post {
                always {
                    publishHTML(target: [
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'zap-reports',
                        reportFiles: 'zap_report.html',
                        reportName: 'ZAP DAST Report'
                    ])
                }
            }
        }

        stage('Deploy to Production (Ansible)') {
            steps {
                sshagent(['ansible-ssh-key']) {
                    sh '''
                        ansible-playbook -i ansible/inventory.ini \
                            ansible/deploy.yml \
                            --extra-vars "artifact_path=${WORKSPACE}/target/spring-petclinic-*.jar"
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
        }
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}
