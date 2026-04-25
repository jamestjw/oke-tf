locals {
  cert_manager_acme_enabled = alltrue([
    var.cert_manager_acme_email != null && trimspace(var.cert_manager_acme_email) != "",
    var.cert_manager_dns_zone != null && trimspace(var.cert_manager_dns_zone) != "",
    var.cloudflare_api_token != null && trimspace(var.cloudflare_api_token) != "",
  ])

  ingress_default_wildcard_certificate_enabled = local.cert_manager_acme_enabled && var.ingress_default_wildcard_certificate_enabled

  cloudflare_zone_name = coalesce(var.cloudflare_zone_name, var.cert_manager_dns_zone)
}

resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = var.ingress_namespace
  }
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = var.cert_manager_namespace
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
  }
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_chart_version
  namespace        = kubernetes_namespace.ingress_nginx.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 900

  values = [
    yamlencode({
      controller = merge({
        service = {
          type                  = "LoadBalancer"
          externalTrafficPolicy = var.ingress_service_external_traffic_policy
          annotations           = var.ingress_service_annotations
        }
        }, local.ingress_default_wildcard_certificate_enabled ? {
        extraArgs = {
          default-ssl-certificate = "${kubernetes_namespace.ingress_nginx.metadata[0].name}/${var.ingress_default_wildcard_certificate_secret_name}"
        }
      } : {})
    })
  ]
}

data "kubernetes_service_v1" "ingress_nginx_controller" {
  metadata {
    name      = var.ingress_controller_service_name
    namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
  }

  depends_on = [helm_release.ingress_nginx]
}

data "cloudflare_zone" "selected" {
  count = local.cloudflare_zone_name != null ? 1 : 0
  name  = local.cloudflare_zone_name
}

locals {
  ingress_external_hostname_raw = try(data.kubernetes_service_v1.ingress_nginx_controller.status[0].load_balancer[0].ingress[0].hostname, null)
  ingress_external_ip_raw       = try(data.kubernetes_service_v1.ingress_nginx_controller.status[0].load_balancer[0].ingress[0].ip, null)

  ingress_external_hostname = local.ingress_external_hostname_raw != null && trimspace(local.ingress_external_hostname_raw) != "" ? trimsuffix(trimspace(local.ingress_external_hostname_raw), ".") : null
  ingress_external_ip       = local.ingress_external_ip_raw != null && trimspace(local.ingress_external_ip_raw) != "" ? trimspace(local.ingress_external_ip_raw) : null

  cloudflare_argocd_record_name = var.argocd_hostname != null && local.cloudflare_zone_name != null ? trimsuffix(var.argocd_hostname, ".${local.cloudflare_zone_name}") : null

  cloudflare_wildcard_record_name = local.cloudflare_zone_name != null ? "*" : null

  ingress_external_record_type  = local.ingress_external_hostname != null ? "CNAME" : "A"
  ingress_external_record_value = local.ingress_external_hostname != null ? local.ingress_external_hostname : local.ingress_external_ip
}

resource "cloudflare_record" "argocd" {
  count = var.cloudflare_argocd_dns_record_enabled && local.cloudflare_argocd_record_name != null ? 1 : 0

  zone_id = data.cloudflare_zone.selected[0].id
  name    = local.cloudflare_argocd_record_name
  type    = local.ingress_external_record_type
  content = local.ingress_external_record_value
  proxied = var.cloudflare_dns_record_proxied

  allow_overwrite = true
}

resource "cloudflare_record" "wildcard" {
  count = var.cloudflare_wildcard_dns_record_enabled && local.cloudflare_wildcard_record_name != null ? 1 : 0

  zone_id = data.cloudflare_zone.selected[0].id
  name    = local.cloudflare_wildcard_record_name
  type    = local.ingress_external_record_type
  content = local.ingress_external_record_value
  proxied = var.cloudflare_dns_record_proxied

  allow_overwrite = true
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_chart_version
  namespace        = kubernetes_namespace.cert_manager.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 900

  values = [
    yamlencode({
      crds = {
        enabled = true
      }
      clusterResourceNamespace = var.cert_manager_cluster_resource_namespace
    })
  ]
}

resource "kubernetes_secret_v1" "cloudflare_api_token" {
  count = local.cert_manager_acme_enabled ? 1 : 0

  metadata {
    name      = var.cloudflare_api_token_secret_name
    namespace = var.cert_manager_cluster_resource_namespace
  }

  data = {
    api-token = var.cloudflare_api_token
  }

  depends_on = [helm_release.cert_manager]
}

resource "helm_release" "platform_bootstrap_acme" {
  count = local.cert_manager_acme_enabled ? 1 : 0

  name             = "platform-bootstrap-acme"
  chart            = "${path.module}/charts/platform-bootstrap-acme"
  namespace        = kubernetes_namespace.cert_manager.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 900

  values = [
    yamlencode({
      certManager = {
        clusterIssuerStagingName = var.cluster_issuer_staging_name
        clusterIssuerProdName    = var.cluster_issuer_prod_name
        acmeEmail                = var.cert_manager_acme_email
        stagingServer            = var.cluster_issuer_staging_server
        prodServer               = var.cluster_issuer_prod_server
        dnsZone                  = var.cert_manager_dns_zone
        cloudflare = {
          apiTokenSecretName = var.cloudflare_api_token_secret_name
          apiTokenSecretKey  = "api-token"
        }
      }
      ingress = {
        namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
        wildcardCertificate = {
          enabled    = var.ingress_default_wildcard_certificate_enabled
          name       = var.ingress_default_wildcard_certificate_name
          secretName = var.ingress_default_wildcard_certificate_secret_name
        }
      }
    })
  ]

  depends_on = [
    helm_release.cert_manager,
    helm_release.ingress_nginx,
    kubernetes_secret_v1.cloudflare_api_token,
  ]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 900

  values = [
    yamlencode({
      crds = {
        install = true
      }
      global = {
        domain = var.argocd_hostname
      }
      configs = {
        params = {
          "server.insecure" = tostring(var.argocd_server_insecure)
        }
      }
      server = {
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled          = var.argocd_hostname != null
          ingressClassName = var.argocd_ingress_class_name
          hostname         = var.argocd_hostname
          annotations = local.ingress_default_wildcard_certificate_enabled ? {
            "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
          } : {}
        }
      }
      dex = {
        enabled = false
      }
      redis-ha = {
        enabled = false
      }
      controller = {
        replicas = 1
      }
      repoServer = {
        replicas = 1
      }
      applicationSet = {
        replicas = 1
      }
      notifications = {
        enabled = false
      }
    })
  ]

  depends_on = [
    helm_release.ingress_nginx,
    helm_release.cert_manager,
    helm_release.platform_bootstrap_acme,
  ]
}

resource "kubernetes_secret_v1" "argocd_repository" {
  count = var.argocd_bootstrap_enabled ? 1 : 0

  metadata {
    name      = "argocd-cluster-gitops-repo"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      # This label tells Argo CD to treat the secret as repository credentials
      # and automatically use it when an Application references the same repo URL.
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type     = "git"
    url      = var.argocd_repo_url
    username = var.argocd_repo_username
    password = var.argocd_repo_pat
  }

  lifecycle {
    precondition {
      condition     = var.argocd_repo_pat != null && trimspace(var.argocd_repo_pat) != ""
      error_message = "argocd_repo_pat must be set when argocd_bootstrap_enabled is true."
    }
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_manifest" "argocd_root_application" {
  count = var.argocd_bootstrap_enabled ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = var.argocd_root_application_name
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.argocd_repo_url
        targetRevision = var.argocd_root_application_revision
        path           = var.argocd_root_application_path
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.argocd.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    kubernetes_secret_v1.argocd_repository,
  ]
}
