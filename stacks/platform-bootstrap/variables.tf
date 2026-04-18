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
