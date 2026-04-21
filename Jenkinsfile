pipeline {
    agent any

    environment {
        SONAR_TOKEN = credentials('admin')
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
                // sh './mvnw clean package -DskipTests'
                sh '''
                    rm -rf burp-reports
                    chmod +x mvnw || true
                    ./mvnw clean package -DskipTests -Dnohttp.checkstyle.skip -Dcheckstyle.skip
                '''
            }
        }

        stage('Unit Tests') {
            steps {
                sh '''
                    rm -rf burp-reports
                    ./mvnw test -Pskip-db-tests
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
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
                sshagent(['ansible-ssh-key']) {
                    sh '''
                        JAR_PATH=$(find target -maxdepth 1 -name "*.jar" ! -name "original-*.jar" | head -n 1)

                        if [ -z "$JAR_PATH" ]; then
                        echo "No JAR found in target/"
                        exit 1
                        fi

                        ABS_JAR_PATH=$(readlink -f "$JAR_PATH")

                        echo "Deploying $ABS_JAR_PATH"

                        ansible-playbook -i ansible/inventory.ini \
                        ansible/deploy.yml \
                        -e "artifact_path=$ABS_JAR_PATH" \
                        --ssh-common-args='-o StrictHostKeyChecking=no'
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