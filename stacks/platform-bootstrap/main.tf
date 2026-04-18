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
