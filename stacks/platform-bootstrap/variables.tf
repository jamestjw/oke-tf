variable "kubeconfig_path" {
  type = string
}

variable "ingress_namespace" {
  type    = string
  default = "ingress-nginx"
}

variable "argocd_namespace" {
  type    = string
  default = "argocd"
}

variable "ingress_nginx_chart_version" {
  type    = string
  default = "4.12.1"
}

variable "ingress_controller_service_name" {
  type    = string
  default = "ingress-nginx-controller"
}

variable "argocd_chart_version" {
  type    = string
  default = "7.7.16"
}

variable "cert_manager_namespace" {
  type    = string
  default = "cert-manager"
}

variable "cert_manager_chart_version" {
  type    = string
  default = "v1.18.2"
}

variable "ingress_service_annotations" {
  type = map(string)
  default = {
    "oci.oraclecloud.com/load-balancer-type"                                  = "nlb"
    "oci.oraclecloud.com/security-rule-management-mode"                       = "None"
    "oci-network-load-balancer.oraclecloud.com/security-list-management-mode" = "None"
    "oci-network-load-balancer.oraclecloud.com/is-preserve-source"            = "false"
  }
}

variable "ingress_service_external_traffic_policy" {
  type    = string
  default = "Local"
}

variable "argocd_hostname" {
  type    = string
  default = null
}

variable "argocd_ingress_class_name" {
  type    = string
  default = "nginx"
}

variable "cert_manager_cluster_resource_namespace" {
  type    = string
  default = "cert-manager"
}

variable "cert_manager_acme_email" {
  type    = string
  default = null
}

variable "cert_manager_dns_zone" {
  type    = string
  default = null
}

variable "cloudflare_api_token" {
  type      = string
  default   = null
  sensitive = true
}

variable "cloudflare_api_token_secret_name" {
  type    = string
  default = "cloudflare-api-token"
}

variable "cloudflare_zone_name" {
  type    = string
  default = null
}

variable "cloudflare_argocd_dns_record_enabled" {
  type    = bool
  default = true
}

variable "cloudflare_wildcard_dns_record_enabled" {
  type    = bool
  default = false
}

variable "cloudflare_argocd_dns_record_proxied" {
  type    = bool
  default = true
}

variable "cloudflare_wildcard_dns_record_proxied" {
  type    = bool
  default = false
}

variable "cluster_issuer_prod_name" {
  type    = string
  default = "letsencrypt-prod"
}

variable "cluster_issuer_staging_name" {
  type    = string
  default = "letsencrypt-staging"
}

variable "cluster_issuer_prod_server" {
  type    = string
  default = "https://acme-v02.api.letsencrypt.org/directory"
}

variable "cluster_issuer_staging_server" {
  type    = string
  default = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

variable "ingress_default_wildcard_certificate_enabled" {
  type    = bool
  default = true
}

variable "ingress_default_wildcard_certificate_name" {
  type    = string
  default = "ingress-default-wildcard"
}

variable "ingress_default_wildcard_certificate_secret_name" {
  type    = string
  default = "ingress-default-wildcard-tls"
}

variable "argocd_server_insecure" {
  type    = bool
  default = true
}

variable "argocd_bootstrap_enabled" {
  type    = bool
  default = false
}

variable "argocd_repo_url" {
  type    = string
  default = "https://github.com/jamestjw/cluster-gitops.git"
}

variable "argocd_repo_username" {
  type    = string
  default = "git"
}

variable "argocd_repo_pat" {
  type      = string
  default   = null
  sensitive = true
}

variable "argocd_root_application_name" {
  type    = string
  default = "root-applications"
}

variable "argocd_root_application_path" {
  type    = string
  default = "argocd"
}

variable "argocd_root_application_revision" {
  type    = string
  default = "main"
}
