resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = var.ingress_namespace
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
      controller = {
        service = {
          type                  = "LoadBalancer"
          externalTrafficPolicy = var.ingress_service_external_traffic_policy
          annotations           = var.ingress_service_annotations
        }
      }
    })
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

  depends_on = [helm_release.ingress_nginx]
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

  depends_on = [
    helm_release.argocd,
    helm_release.nfs_provisioner
  ]
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
    helm_release.nfs_provisioner
  ]
}
