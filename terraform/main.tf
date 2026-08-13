terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

variable "kubeconfig_path" {
  type = string
}

resource "kubernetes_namespace" "devops" {
  metadata {
    name = "devops-demo"
  }
}

resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "devops-app-config"
    namespace = kubernetes_namespace.devops.metadata[0].name
  }

  data = {
    RABBITMQ_URL = "amqp://rabbitmq:5672"
  }
}

resource "kubernetes_deployment" "app" {
  metadata {
    name      = "devops-app"
    namespace = kubernetes_namespace.devops.metadata[0].name

    labels = {
      app = "devops-app"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "devops-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "devops-app"
        }
      }

      spec {
        container {
          name  = "devops-app"
          image = "devops-demo-app:3.0"

          port {
            container_port = 3000
          }

          env {
            name = "RABBITMQ_URL"

            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "RABBITMQ_URL"
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "app" {
  metadata {
    name      = "devops-app"
    namespace = kubernetes_namespace.devops.metadata[0].name
  }

  spec {
    selector = {
      app = "devops-app"
    }

    port {
      port        = 3000
      target_port = 3000
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_deployment" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace.devops.metadata[0].name

    labels = {
      app = "rabbitmq"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "rabbitmq"
      }
    }

    template {
      metadata {
        labels = {
          app = "rabbitmq"
        }
      }

      spec {
        container {
          name  = "rabbitmq"
          image = "rabbitmq:3-management"

          port {
            container_port = 5672
          }

          port {
            container_port = 15672
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace.devops.metadata[0].name
  }

  spec {
    selector = {
      app = "rabbitmq"
    }

    port {
      name        = "amqp"
      port        = 5672
      target_port = 5672
    }

    port {
      name        = "management"
      port        = 15672
      target_port = 15672
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_deployment" "worker" {
  metadata {
    name      = "devops-worker"
    namespace = kubernetes_namespace.devops.metadata[0].name

    labels = {
      app = "devops-worker"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "devops-worker"
      }
    }

    template {
      metadata {
        labels = {
          app = "devops-worker"
        }
      }

      spec {
        container {
          name  = "worker"
          image = "devops-worker:1.0"

          env {
            name  = "RABBITMQ_URL"

            value = "amqp://rabbitmq:5672"
          }
        }
      }
    }
  }
}





