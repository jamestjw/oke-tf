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

variable "argocd_chart_version" {
  type    = string
  default = "7.7.16"
}

variable "ingress_service_annotations" {
  type = map(string)
  default = {
    "oci.oraclecloud.com/load-balancer-type"                              = "nlb"
    "oci.oraclecloud.com/security-rule-management-mode"                  = "None"
    "oci-network-load-balancer.oraclecloud.com/security-list-management-mode" = "None"
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

variable "nfs_provisioner_enabled" {
  type        = bool
  default     = true
  description = "Enable the NFS subdir external provisioner to carve up a single OCI Block Volume."
}

variable "nfs_provisioner_namespace" {
  type        = string
  default     = "storage"
  description = "Namespace for the NFS storage provisioner and server."
}

variable "nfs_storage_size" {
  type        = string
  default     = "50Gi"
  description = "Size of the backing OCI Block Volume for the NFS provisioner."
}

variable "nfs_provisioner_chart_version" {
  type        = string
  default     = "4.0.18"
  description = "Helm chart version for nfs-subdir-external-provisioner."
}
