pipeline {

    agent any

    parameters {
        string(
            name: 'KUBECONFIG_CREDENTIAL_ID',
            defaultValue: 'kubeconfig-devops',
            description: 'Jenkins Secret file credential ID for kubeconfig access'
        )
        string(
            name: 'PROD_APPROVERS',
            defaultValue: 'admin',
            description: 'Comma-separated Jenkins usernames allowed to approve production deploy'
        )
    }

    environment {
        KUBECONFIG = "${WORKSPACE}/.kube/config"
        TF_VAR_kubeconfig_path = "${WORKSPACE}/.kube/config"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Check Tools') {
            steps { 
                sh 'docker --version'
                sh 'terraform version'
                sh '''
                    set -e
                    mkdir -p .tools/bin

                    if ! command -v kubectl >/dev/null 2>&1; then
                      ARCH="$(uname -m)"
                      if [ "$ARCH" = "x86_64" ]; then
                        K8S_ARCH="amd64"
                      elif [ "$ARCH" = "aarch64" ]; then
                        K8S_ARCH="arm64"
                      else
                        echo "Unsupported architecture: $ARCH"
                        exit 1
                      fi

                      KUBECTL_VERSION="v1.31.12"
                      curl -fsSLo .tools/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${K8S_ARCH}/kubectl"
                      chmod +x .tools/bin/kubectl
                    fi

                    export PATH="$PWD/.tools/bin:$PATH"
                    kubectl version --client
                '''
            }
        }

        stage('Prepare Kubernetes Access') {
            steps {
                script {
                    def kubeconfigReady = false

                    sh '''
                        set -e
                        mkdir -p "$WORKSPACE/.kube"
                    '''

                    try {
                        withCredentials([file(credentialsId: params.KUBECONFIG_CREDENTIAL_ID, variable: 'KUBECONFIG_FILE')]) {
                            sh '''
                                set -e
                                cp "$KUBECONFIG_FILE" "$WORKSPACE/.kube/config"
                            '''
                        }
                        kubeconfigReady = true
                        echo "Loaded kubeconfig from Jenkins credentials ID: ${params.KUBECONFIG_CREDENTIAL_ID}"
                    } catch (err) {
                        echo "Credential ID '${params.KUBECONFIG_CREDENTIAL_ID}' not found or inaccessible. Trying existing ~/.kube/config on Jenkins node."
                    }

                    if (!kubeconfigReady) {
                        sh '''
                            set -e
                            test -r "$HOME/.kube/config"
                            cp "$HOME/.kube/config" "$WORKSPACE/.kube/config"
                        '''
                    }

                    sh '''
                        set -e
                        export KUBECONFIG="$WORKSPACE/.kube/config"
                        KUBECTL_BIN="$(command -v kubectl || true)"
                        if [ -z "$KUBECTL_BIN" ]; then
                          KUBECTL_BIN="$PWD/.tools/bin/kubectl"
                        fi

                        "$KUBECTL_BIN" config current-context
                        "$KUBECTL_BIN" cluster-info
                    '''
                }
            }
        }

        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    withEnv([
                        "KUBECONFIG=${env.WORKSPACE}/.kube/config",
                        "TF_VAR_kubeconfig_path=${env.WORKSPACE}/.kube/config"
                    ]) {
                        sh 'terraform init'
                    }
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                dir('terraform') {
                    withEnv([
                        "KUBECONFIG=${env.WORKSPACE}/.kube/config",
                        "TF_VAR_kubeconfig_path=${env.WORKSPACE}/.kube/config"
                    ]) {
                        sh 'terraform validate'
                    }
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                script {
                    env.IMAGE_TAG = "v${env.BUILD_NUMBER}"
                    sh "docker build -t devops-demo-app:${env.IMAGE_TAG} ./app"
                    sh "docker build -t devops-worker:${env.IMAGE_TAG} ./worker"
                    // Catatan: Jika ada registry (Docker Hub/Harbor), tambahkan 'docker push' di sini
                }
            }
        }

        stage('Unit Test App') {
            steps {
                sh "docker run --rm devops-demo-app:${env.IMAGE_TAG} npm run test"
            }
        }

        stage('Terraform Plan (Dev)') {
            steps {
                dir('terraform') {
                    withEnv([
                        "KUBECONFIG=${env.WORKSPACE}/.kube/config",
                        "TF_VAR_kubeconfig_path=${env.WORKSPACE}/.kube/config",
                        "TF_VAR_app_image_tag=${env.IMAGE_TAG}",
                        "TF_VAR_worker_image_tag=${env.IMAGE_TAG}"
                    ]) {
                        sh 'terraform workspace select dev || terraform workspace new dev'
                        sh 'terraform plan'
                    }
                }
            }
        }

        stage('Terraform Apply (Dev)') {
            steps {
                dir('terraform') {
                    withEnv([
                        "KUBECONFIG=${env.WORKSPACE}/.kube/config",
                        "TF_VAR_kubeconfig_path=${env.WORKSPACE}/.kube/config",
                        "TF_VAR_app_image_tag=${env.IMAGE_TAG}",
                        "TF_VAR_worker_image_tag=${env.IMAGE_TAG}"
                    ]) {
                        sh 'terraform apply -auto-approve'
                    }
                }
            }
        }

        stage('Approval for Prod') {
            steps {
                script {
                    timeout(time: 30, unit: 'MINUTES') {
                        def approvedBy = input(
                            message: 'Deploy to Production?',
                            ok: 'Yes, Deploy',
                            submitter: params.PROD_APPROVERS,
                            submitterParameter: 'APPROVED_BY'
                        )
                        echo "Production deployment approved by: ${approvedBy}"
                    }
                }
            }
        }

        stage('Terraform Plan (Prod)') {
            steps {
                dir('terraform') {
                    withEnv([
                        "KUBECONFIG=${env.WORKSPACE}/.kube/config",
                        "TF_VAR_kubeconfig_path=${env.WORKSPACE}/.kube/config",
                        "TF_VAR_app_image_tag=${env.IMAGE_TAG}",
                        "TF_VAR_worker_image_tag=${env.IMAGE_TAG}"
                    ]) {
                        sh 'terraform workspace select prod || terraform workspace new prod'
                        sh 'terraform plan'
                    }
                }
            }
        }

        stage('Terraform Apply (Prod)') {
            steps {
                dir('terraform') {
                    withEnv([
                        "KUBECONFIG=${env.WORKSPACE}/.kube/config",
                        "TF_VAR_kubeconfig_path=${env.WORKSPACE}/.kube/config",
                        "TF_VAR_app_image_tag=${env.IMAGE_TAG}",
                        "TF_VAR_worker_image_tag=${env.IMAGE_TAG}"
                    ]) {
                        sh 'terraform apply -auto-approve'
                    }
                }
            }
        }
    }
}