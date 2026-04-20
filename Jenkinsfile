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
                        chmod +x mvnw || true
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
                    //waitForQualityGate abortPipeline: false 
                    //ym modified: true->false
                }
            }
        }

        stage('Burp Suite Scan') {
            steps {
                sh '''
                    mkdir -p burp-reports

                    # Start the app temporarily
                    java -jar target/*.jar --server.port=9966 &
                    APP_PID=$!

                    # Wait for app to be ready
                    echo "Waiting for app to start..."
                    for i in $(seq 1 20); do
                        curl -s http://localhost:9966/actuator/health && break
                        sleep 5
                    done

                    # Get Jenkins IP
                    JENKINS_IP=$(hostname -I | awk '{print $1}' | tr -d '[:space:]')
                    echo "Jenkins IP: $JENKINS_IP"

                    # Spider only - no active scan
                    curl -s "http://burpsuite:8080/JSON/spider/action/scan/?url=http://${JENKINS_IP}:9966&maxChildren=10" || true
                    sleep 30

                    # Generate report
                    curl -s "http://burpsuite:8080/OTHER/core/other/htmlreport/" > burp-reports/burp_report.html

                    # Stop the app
                    kill $APP_PID || true

                    echo "ZAP scan complete!"
                '''
            }
            post {
                always {
                    publishHTML(target: [
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'burp-reports',
                        reportFiles: 'burp_report.html',
                        reportName: 'Burp Suite Report'
                    ])
                }
            }
        }

        stage('Deploy to Production (Ansible)') {
            steps {
                // sshagent(['ansible-ssh-key']) {
                //     sh '''
                //         ansible-playbook -i ansible/inventory.ini \
                //             ansible/deploy.yml \
                //             --extra-vars "artifact_path=${WORKSPACE}/target/spring-petclinic-*.jar"
                //     '''
                // }
                //  sh '''
                //  /home/lili/.local/bin/ansible-playbook -i ansible/inventory.ini \
                //  ansible/deploy.yml \
                //  --extra-vars "ansible_ssh_extra_args='-o StrictHostKeyChecking=no'"
                //  '''
                //sh "ssh -o StrictHostKeyChecking=no lili@10.0.0.50 '~/.local/bin/ansible-playbook -i ~/spring-petclinic_team8/ansible/inventory.ini ~/spring-petclinic_team8/ansible/deploy.yml'"
                sshagent(['ansible-ssh-key']){
                    sh "ssh -o StrictHostKeyChecking=no lili@10.0.0.50 '~/.local/bin/ansible-playbook -i ~/spring-petclinic_team8/ansible/inventory.ini ~/spring-petclinic_team8/ansible/deploy.yml'"
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