output "ingress_nginx_namespace" {
  value = kubernetes_namespace.ingress_nginx.metadata[0].name
}

output "argocd_namespace" {
  value = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_admin_password_command" {
  value = "kubectl -n ${kubernetes_namespace.argocd.metadata[0].name} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && printf '\n'"
}

output "argocd_root_application_name" {
  value = var.argocd_bootstrap_enabled ? kubernetes_manifest.argocd_root_application[0].manifest.metadata.name : null
}
