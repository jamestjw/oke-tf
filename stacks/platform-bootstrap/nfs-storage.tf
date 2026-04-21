resource "kubernetes_namespace" "nfs_provisioner" {
  count = var.nfs_provisioner_enabled ? 1 : 0
  metadata {
    name = var.nfs_provisioner_namespace
  }
}

resource "kubernetes_persistent_volume_claim" "nfs_master_pvc" {
  count = var.nfs_provisioner_enabled ? 1 : 0
  metadata {
    name      = "nfs-master-pvc"
    namespace = kubernetes_namespace.nfs_provisioner[0].metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "oci-bv"
    resources {
      requests = {
        storage = var.nfs_storage_size
      }
    }
  }
}

resource "kubernetes_deployment" "nfs_server" {
  count = var.nfs_provisioner_enabled ? 1 : 0
  metadata {
    name      = "nfs-server"
    namespace = kubernetes_namespace.nfs_provisioner[0].metadata[0].name
  }
  spec {
    replicas = 1
    strategy {
      type = "Recreate"
    }
    selector {
      match_labels = {
        app = "nfs-server"
      }
    }
    template {
      metadata {
        labels = {
          app = "nfs-server"
        }
      }
      spec {
        container {
          name  = "nfs-server"
          image = "erichough/nfs-server:latest"
          env {
            name  = "NFS_EXPORT_0"
            value = "/exports *(rw,fsid=0,insecure,no_root_squash,no_subtree_check,sync)"
          }
          port {
            name           = "nfs"
            container_port = 2049
          }
          security_context {
            privileged = true
            capabilities {
              add = ["SYS_ADMIN", "SETPCAP"]
            }
          }
          volume_mount {
            mount_path = "/exports"
            name       = "storage"
          }
        }
        volume {
          name = "storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.nfs_master_pvc[0].metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nfs_server" {
  count = var.nfs_provisioner_enabled ? 1 : 0
  metadata {
    name      = "nfs-server"
    namespace = kubernetes_namespace.nfs_provisioner[0].metadata[0].name
  }
  spec {
    selector = {
      app = "nfs-server"
    }
    port {
      name = "nfs"
      port = 2049
    }
    cluster_ip = "None"
  }
}

resource "helm_release" "nfs_provisioner" {
  count            = var.nfs_provisioner_enabled ? 1 : 0
  name             = "nfs-provisioner"
  repository       = "https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/"
  chart            = "nfs-subdir-external-provisioner"
  version          = var.nfs_provisioner_chart_version
  namespace        = kubernetes_namespace.nfs_provisioner[0].metadata[0].name
  create_namespace = false
  wait             = true

  set {
    name  = "nfs.server"
    value = "${kubernetes_service.nfs_server[0].metadata[0].name}.${kubernetes_namespace.nfs_provisioner[0].metadata[0].name}.svc.cluster.local"
  }

  set {
    name  = "nfs.path"
    value = "/exports"
  }

  set {
    name  = "storageClass.name"
    value = "nfs-client"
  }

  set {
    name  = "storageClass.defaultClass"
    value = "true"
  }

  depends_on = [
    kubernetes_deployment.nfs_server,
    kubernetes_service.nfs_server
  ]
}
