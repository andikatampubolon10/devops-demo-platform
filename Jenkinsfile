pipeline {

    agent any

    options {
        // Cegah concurrent build yang menyebabkan workspace @2 dengan state kosong
        disableConcurrentBuilds()
    }

    parameters {
        string(
            name: 'KUBECONFIG_CREDENTIAL_ID',
            defaultValue: 'kubeconfig-devops',
            description: 'Jenkins Secret file credential ID for kubeconfig access'
        )
        string(
            name: 'IMAGE_VERSION',
            defaultValue: '',
            description: 'Versi image yang di-BUILD (contoh: v1.2.0). Kosongkan = otomatis v{BUILD_NUMBER}.'
        )
        string(
            name: 'PROD_IMAGE_TAG',
            defaultValue: '',
            description: 'Versi image yang di-DEPLOY ke Production (contoh: v32). Kosongkan = pakai versi yang baru di-build di pipeline ini.'
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
                    // Gunakan IMAGE_VERSION dari parameter jika diisi, fallback ke nomor build otomatis
                    env.IMAGE_TAG = (params.IMAGE_VERSION?.trim()) ? params.IMAGE_VERSION.trim() : "v${env.BUILD_NUMBER}"
                    echo "Image tag yang digunakan: ${env.IMAGE_TAG}"

                    sh "docker build -t devops-demo-app:${env.IMAGE_TAG} ./app"
                    sh "docker tag devops-demo-app:${env.IMAGE_TAG} devops-demo-app:latest"

                    sh "docker build -t devops-worker:${env.IMAGE_TAG} ./worker"
                    sh "docker tag devops-worker:${env.IMAGE_TAG} devops-worker:latest"

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
                        // Auto-import resources yang sudah ada agar tidak error "already exists"
                        sh '''
                            NS="devops-demo-dev"
                            terraform workspace select dev || terraform workspace new dev

                            # Import namespace jika belum ada di state
                            if kubectl get namespace "$NS" > /dev/null 2>&1; then
                              if ! terraform state list | grep -q "kubernetes_namespace.devops"; then
                                echo "Importing existing namespace $NS into Terraform state..."
                                terraform import kubernetes_namespace.devops "$NS"
                              fi
                            fi
                        '''
                        sh 'terraform apply -auto-approve'
                    }
                }
            }
        }

        stage('Approval for Prod') {
            // PENTING: agent none melepas executor Jenkins saat menunggu input manusia.
            // Tanpa ini, executor ter-block dan klik tombol akan loading selamanya (deadlock).
            agent none
            steps {
                script {
                    // Tentukan versi yang akan naik ke prod
                    // Jika PROD_IMAGE_TAG diisi → pakai itu (bisa rollback ke versi lama)
                    // Jika kosong → pakai versi yang baru di-build (env.IMAGE_TAG)
                    def prodTag = (params.PROD_IMAGE_TAG?.trim()) ? params.PROD_IMAGE_TAG.trim() : env.IMAGE_TAG
                    env.PROD_TAG = prodTag

                    // Tampilkan info jelas sebelum approval
                    echo """\n
============================================================
SIAP DEPLOY KE PRODUCTION
------------------------------------------------------------
   Versi yang baru di-build  : ${env.IMAGE_TAG}
   Versi yang akan ke PROD   : ${env.PROD_TAG}
------------------------------------------------------------
Jika PROD_IMAGE_TAG dikosongkan, versi yang di-build sekarang
akan langsung dipromosikan ke Production.
============================================================
"""

                    input(
                        message: "Deploy devops-demo-app:${env.PROD_TAG} ke Production?",
                        ok: "Ya, Deploy ke Prod",
                        submitter: "admin,andikatampubolon10"
                    )
                }
            }
        }

        stage('Terraform Plan (Prod)') {
            steps {
                dir('terraform') {
                    withEnv([
                        "KUBECONFIG=${env.WORKSPACE}/.kube/config",
                        "TF_VAR_kubeconfig_path=${env.WORKSPACE}/.kube/config",
                        "TF_VAR_app_image_tag=${env.PROD_TAG}",
                        "TF_VAR_worker_image_tag=${env.PROD_TAG}"
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
                        "TF_VAR_app_image_tag=${env.PROD_TAG}",
                        "TF_VAR_worker_image_tag=${env.PROD_TAG}"
                    ]) {
                        sh 'terraform apply -auto-approve'
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    echo """\n
============================================================
✅ DEPLOYMENT SELESAI!
------------------------------------------------------------
   Build Number              : ${env.BUILD_NUMBER}
   Image yang di-build       : ${env.IMAGE_TAG}
   Image yang naik ke Prod   : ${env.PROD_TAG}
============================================================
"""
                }
                sh '''
                    set -e
                    export KUBECONFIG="$WORKSPACE/.kube/config"
                    KUBECTL_BIN="$(command -v kubectl || echo "$PWD/.tools/bin/kubectl")"

                    echo "--- Pod yang berjalan di namespace 'dev' ---"
                    "$KUBECTL_BIN" get pods -n dev -o wide || true

                    echo ""
                    echo "--- Image yang digunakan oleh pod devops-app (dev) ---"
                    "$KUBECTL_BIN" get pods -n dev -l app=devops-app \
                        -o jsonpath="{range .items[*]}{.metadata.name}: {.spec.containers[*].image}{'\\n'}{end}" || true
                '''
            }
        }
    }
}