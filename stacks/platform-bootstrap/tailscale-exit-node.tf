resource "kubernetes_namespace_v1" "tailscale" {
  count = var.enable_tailscale_exit_node ? 1 : 0

  metadata {
    name = var.tailscale_namespace
  }
}

resource "kubernetes_secret_v1" "tailscale_auth" {
  count = var.enable_tailscale_exit_node ? 1 : 0

  metadata {
    name      = var.tailscale_auth_secret_name
    namespace = kubernetes_namespace_v1.tailscale[0].metadata[0].name
  }

  data = {
    TS_AUTHKEY = coalesce(var.tailscale_auth_key, "")
  }

  lifecycle {
    precondition {
      condition     = var.tailscale_auth_key != null && trimspace(var.tailscale_auth_key) != ""
      error_message = "tailscale_auth_key must be set when enable_tailscale_exit_node is true."
    }
  }
}

resource "kubernetes_secret_v1" "tailscale_state" {
  count = var.enable_tailscale_exit_node ? 1 : 0

  metadata {
    name      = var.tailscale_state_secret_name
    namespace = kubernetes_namespace_v1.tailscale[0].metadata[0].name
  }

  lifecycle {
    ignore_changes = [data]
  }
}

resource "kubernetes_service_account_v1" "tailscale" {
  count = var.enable_tailscale_exit_node ? 1 : 0

  metadata {
    name      = var.tailscale_exit_node_name
    namespace = kubernetes_namespace_v1.tailscale[0].metadata[0].name
  }
}

resource "kubernetes_role_v1" "tailscale" {
  count = var.enable_tailscale_exit_node ? 1 : 0

  metadata {
    name      = var.tailscale_exit_node_name
    namespace = kubernetes_namespace_v1.tailscale[0].metadata[0].name
  }

  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = [kubernetes_secret_v1.tailscale_state[0].metadata[0].name]
    verbs          = ["get", "update", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["get", "create", "patch"]
  }
}

resource "kubernetes_role_binding_v1" "tailscale" {
  count = var.enable_tailscale_exit_node ? 1 : 0

  metadata {
    name      = var.tailscale_exit_node_name
    namespace = kubernetes_namespace_v1.tailscale[0].metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.tailscale[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.tailscale[0].metadata[0].name
    namespace = kubernetes_namespace_v1.tailscale[0].metadata[0].name
  }
}

resource "kubernetes_deployment_v1" "tailscale_exit_node" {
  count = var.enable_tailscale_exit_node ? 1 : 0

  metadata {
    name      = var.tailscale_exit_node_name
    namespace = kubernetes_namespace_v1.tailscale[0].metadata[0].name
    labels = {
      app = var.tailscale_exit_node_name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = var.tailscale_exit_node_name
      }
    }

    template {
      metadata {
        labels = {
          app = var.tailscale_exit_node_name
        }
      }

      spec {
        host_network         = true
        dns_policy           = "ClusterFirstWithHostNet"
        service_account_name = kubernetes_service_account_v1.tailscale[0].metadata[0].name

        container {
          name  = "tailscale"
          image = var.tailscale_image

          env {
            name = "TS_AUTHKEY"

            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.tailscale_auth[0].metadata[0].name
                key  = "TS_AUTHKEY"
              }
            }
          }

          env {
            name  = "TS_EXTRA_ARGS"
            value = "--advertise-exit-node --hostname=${var.tailscale_exit_node_hostname}"
          }

          env {
            name  = "TS_KUBE_SECRET"
            value = kubernetes_secret_v1.tailscale_state[0].metadata[0].name
          }

          env {
            name  = "TS_USERSPACE"
            value = "false"
          }

          security_context {
            privileged = true

            capabilities {
              add = ["NET_ADMIN", "SYS_MODULE"]
            }
          }

          volume_mount {
            name       = "dev-net-tun"
            mount_path = "/dev/net/tun"
          }

        }

        volume {
          name = "dev-net-tun"

          host_path {
            path = "/dev/net/tun"
          }
        }

      }
    }
  }

  depends_on = [
    kubernetes_role_binding_v1.tailscale,
    kubernetes_secret_v1.tailscale_auth,
    kubernetes_secret_v1.tailscale_state,
  ]
}
