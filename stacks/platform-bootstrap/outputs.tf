output "ingress_nginx_namespace" {
  value = kubernetes_namespace.ingress_nginx.metadata[0].name
}

output "argocd_namespace" {
  value = kubernetes_namespace.argocd.metadata[0].name
}

output "cert_manager_namespace" {
  value = kubernetes_namespace.cert_manager.metadata[0].name
}

output "argocd_admin_password_command" {
  value = "kubectl -n ${kubernetes_namespace.argocd.metadata[0].name} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && printf '\n'"
}

output "argocd_root_application_name" {
  value = var.argocd_bootstrap_enabled ? kubernetes_manifest.argocd_root_application[0].manifest.metadata.name : null
}

output "cert_manager_cluster_issuer_prod_name" {
  value = nonsensitive(local.cert_manager_acme_enabled ? var.cluster_issuer_prod_name : null)
}

output "cert_manager_cluster_issuer_staging_name" {
  value = nonsensitive(local.cert_manager_acme_enabled ? var.cluster_issuer_staging_name : null)
}

output "ingress_default_wildcard_certificate_secret_name" {
  value = nonsensitive(local.ingress_default_wildcard_certificate_enabled ? var.ingress_default_wildcard_certificate_secret_name : null)
}

output "ingress_external_hostname" {
  value = nonsensitive(local.ingress_external_hostname)
}

output "ingress_external_ip" {
  value = nonsensitive(local.ingress_external_ip)
}
