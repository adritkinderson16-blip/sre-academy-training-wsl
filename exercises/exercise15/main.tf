resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_deployment" "app_deployment" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
    labels = {
      app = var.app_name
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = var.app_name
      }
    }

    template {
      metadata {
        labels = {
          app = var.app_name
        }
      }

      spec {
        container {
          name              = var.app_name
          image             = var.image
          image_pull_policy = "Never"

          env {
            name  = "MESSAGE_TEXT"
            value = kubernetes_config_map.app_config.data["MESSAGE_TEXT"]
          }

          env {
            name  = "REDIS_HOST"
            value = kubernetes_service.redis.metadata[0].name
          }

          env {
            name  = "REDIS_PORT"
            value = "6379"
          }

          port {
            container_port = var.container_port
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "app_service" {
  metadata {
    name      = "${var.app_name}-service"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }

  spec {
    selector = {
      app = var.app_name
    }

    port {
      port        = var.service_port
      target_port = var.container_port
    }

    type = "NodePort"
  }
}