pipeline {

    agent any

    parameters {
        string(
            name: 'KUBECONFIG_CREDENTIAL_ID',
            defaultValue: 'kubeconfig-devops',
            description: 'Jenkins Secret file credential ID for kubeconfig access'
        )
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
                    def kubeconfigTarget = "${env.WORKSPACE}/.kube/config"

                    sh '''
                        set -e
                        mkdir -p "$WORKSPACE/.kube"
                    '''

                    try {
                        withCredentials([file(credentialsId: params.KUBECONFIG_CREDENTIAL_ID, variable: 'KUBECONFIG_FILE')]) {
                            sh """
                                set -e
                                cp \"$KUBECONFIG_FILE\" \"${kubeconfigTarget}\"
                            """
                        }
                        kubeconfigReady = true
                        echo "Loaded kubeconfig from Jenkins credentials ID: ${params.KUBECONFIG_CREDENTIAL_ID}"
                    } catch (err) {
                        echo "Credential ID '${params.KUBECONFIG_CREDENTIAL_ID}' not found or inaccessible. Trying existing ~/.kube/config on Jenkins node."
                    }

                    if (!kubeconfigReady) {
                        sh """
                            set -e
                            test -r "$HOME/.kube/config"
                            cp "$HOME/.kube/config" "${kubeconfigTarget}"
                        """
                    }

                    sh """
                        set -e
                        export KUBECONFIG=\"${kubeconfigTarget}\"
                        KUBECTL_BIN="$(command -v kubectl || true)"
                        if [ -z "$KUBECTL_BIN" ]; then
                          KUBECTL_BIN="$PWD/.tools/bin/kubectl"
                        fi

                        "$KUBECTL_BIN" config current-context
                        "$KUBECTL_BIN" cluster-info
                    """
                }
            }
        }

        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    withEnv(["KUBECONFIG=${env.WORKSPACE}/.kube/config"]) {
                        sh 'terraform init'
                    }
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                dir('terraform') {
                    withEnv(["KUBECONFIG=${env.WORKSPACE}/.kube/config"]) {
                        sh 'terraform validate'
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                dir('terraform') {
                    withEnv(["KUBECONFIG=${env.WORKSPACE}/.kube/config"]) {
                        sh 'terraform plan'
                    }
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                dir('terraform') {
                    withEnv(["KUBECONFIG=${env.WORKSPACE}/.kube/config"]) {
                        sh 'terraform apply -auto-approve'
                    }
                }
            }
        }
    }
}