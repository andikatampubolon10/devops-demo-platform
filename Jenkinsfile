pipeline {

    agent any

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

        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                dir('terraform') {
                    sh 'terraform validate'
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                dir('terraform') {
                    sh 'terraform plan'
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                dir('terraform') {
                    sh 'terraform apply -auto-approve'
                }
            }
        }
    }
}