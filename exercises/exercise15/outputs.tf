output "namespace" {
  value = kubernetes_namespace.app_namespace.metadata[0].name
}

output "deployment_name" {
  value = kubernetes_deployment.app_deployment.metadata[0].name
}

output "service_name" {
  value = kubernetes_service.app_service.metadata[0].name
}