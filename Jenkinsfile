pipeline {
    // Runs on the Jenkins agent node that has the label "linux-agent"
    agent { label 'linux-agent' }

    options {
        disableConcurrentBuilds()
        timeout(time: 20, unit: 'MINUTES')
    }

    environment {
        DOCKERHUB_USER = '19901418'
        DOCKERHUB_REPO = 'prt-oct-25th'            // your Docker Hub repository name
        KUBE_SERVER_IP = '172.31.42.35'            // kube-server private IP
        KUBE_SSH_USER  = 'ubuntu'

        IMAGE_NAME = "${DOCKERHUB_USER}/${DOCKERHUB_REPO}"
        IMAGE_TAG  = "${BUILD_NUMBER}"
        APP_DIR    = '/home/ubuntu/jakey-shoes'    // folder on kube-server
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Check Tools') {
            steps {
                sh '''
                    docker --version
                    ssh -V
                '''
            }
        }

        stage('Prepare Manifests') {
            steps {
                // Finds deployment/service files anywhere in the repo, with .yml or .yaml,
                // and gathers them into one "manifests" folder.
                sh '''
                    rm -rf manifests && mkdir manifests

                    find . -path ./manifests -prune -o -type f \
                         \\( -name "deployment.yml" -o -name "deployment.yml" \
                            -o -name "service.yml"  -o -name "service.yml" \\) \
                         -print -exec cp {} manifests/ \\;

                    echo "---- Files in workspace ----"
                    ls -la
                    echo "---- Manifests found ----"
                    ls -la manifests

                    # Fail early with a clear message if either file is missing
                    ls manifests/deployment.yml manifests/service.yml

                    # Put the new image into the deployment file
                    grep -q IMAGE_PLACEHOLDER manifests/deployment.yml || echo "WARNING: IMAGE_PLACEHOLDER not found in deployment file"
                    sed -i "s|IMAGE_PLACEHOLDER|${IMAGE_NAME}:${IMAGE_TAG}|g" manifests/deployment.yml
                '''
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
                // dockerhub-cred = Username with password (global)
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
                // ubuntu-cred = SSH Username with private key (global)
                sshagent(credentials: ['ubuntu-cred']) {
                    sh '''
                        SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

                        # Fresh folder on kube-server, then copy the manifests
                        ssh $SSH_OPTS ${KUBE_SSH_USER}@${KUBE_SERVER_IP} "rm -rf ${APP_DIR} && mkdir -p ${APP_DIR}"
                        scp $SSH_OPTS manifests/* ${KUBE_SSH_USER}@${KUBE_SERVER_IP}:${APP_DIR}/

                        # Apply and wait for rollout
                        ssh $SSH_OPTS ${KUBE_SSH_USER}@${KUBE_SERVER_IP} "
                            ls -la ${APP_DIR} &&
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
