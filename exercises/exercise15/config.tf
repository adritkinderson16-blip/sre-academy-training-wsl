resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "app-config"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }
  data = {
    "MESSAGE_TEXT" = "Hello from the SRE Academy!"
  }
}