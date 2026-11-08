pipeline {
    // Runs on the Jenkins agent node labelled "build-agent"
    agent { label 'build-agent' }

    options {
        disableConcurrentBuilds()
        timeout(time: 20, unit: 'MINUTES')
    }

    environment {
        // ====== CHANGE THESE THREE VALUES ======
        DOCKERHUB_USER = 'your-dockerhub-username'
        KUBE_SERVER_IP = 'PRIVATE-IP-OF-kube-server'   // e.g. 172.31.10.25
        KUBE_SSH_USER  = 'ubuntu'
        // =======================================

        IMAGE_NAME = "${DOCKERHUB_USER}/jakey-shoes"
        IMAGE_TAG  = "${BUILD_NUMBER}"
        APP_DIR    = '/home/ubuntu/jakey-shoes'          // folder on kube-server
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest .
                '''
            }
        }

        stage('Push to Docker Hub') {
            steps {
                // dockerhub-cred = "Username with password" (use a Docker Hub access token as password)
                withCredentials([usernamePassword(credentialsId: 'dockerhub-cred',
                                                  usernameVariable: 'DH_USER',
                                                  passwordVariable: 'DH_PASS')]) {
                    sh '''
                        echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
                        docker push ${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${IMAGE_NAME}:latest
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy to Minikube') {
            steps {
                // ubuntu-cred = "SSH Username with private key"
                sshagent(credentials: ['ubuntu-cred']) {
                    sh '''
                        SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

                        # Put the new image tag into the manifest
                        sed -i "s|IMAGE_PLACEHOLDER|${IMAGE_NAME}:${IMAGE_TAG}|g" k8s/deployment.yaml

                        # Copy manifests to kube-server
                        ssh $SSH_OPTS ${KUBE_SSH_USER}@${KUBE_SERVER_IP} "mkdir -p ${APP_DIR}"
                        scp $SSH_OPTS k8s/*.yaml ${KUBE_SSH_USER}@${KUBE_SERVER_IP}:${APP_DIR}/

                        # Apply and wait for rollout
                        ssh $SSH_OPTS ${KUBE_SSH_USER}@${KUBE_SERVER_IP} "
                            kubectl apply -f ${APP_DIR}/ &&
                            kubectl rollout status deployment/jakey-shoes --timeout=120s &&
                            kubectl get pods,svc -l app=jakey-shoes
                        "
                    '''
                }
            }
        }
    }

    post {
        always {
            sh '''
                docker rmi ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest || true
                docker image prune -f || true
            '''
        }
        success { echo "Deployed ${IMAGE_NAME}:${IMAGE_TAG} to minikube." }
        failure { echo "Pipeline failed. Check the stage logs above." }
    }
}
