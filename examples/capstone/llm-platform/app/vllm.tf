locals {
  namespace = "ml-serving"
  labels    = { app = "vllm" }
  image     = "${var.region}-docker.pkg.dev/${var.project_id}/dockerhub/vllm/vllm-openai:${var.vllm_version}"
}

resource "kubernetes_namespace_v1" "serving" {
  metadata {
    name = local.namespace
  }
}

# The KSA that Workload Identity grants objectViewer on the models bucket.
resource "kubernetes_service_account_v1" "vllm" {
  metadata {
    name      = "vllm"
    namespace = kubernetes_namespace_v1.serving.metadata[0].name
  }
}

resource "kubernetes_deployment_v1" "vllm" {
  metadata {
    name      = "vllm"
    namespace = kubernetes_namespace_v1.serving.metadata[0].name
    labels    = local.labels
  }

  # A GPU node takes several minutes to appear; don't fail the apply meanwhile.
  wait_for_rollout = false

  spec {
    replicas = 1

    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels
        annotations = {
          "gke-gcsfuse/volumes" = "true" # inject the GCS FUSE sidecar
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.vllm.metadata[0].name

        node_selector = {
          "cloud.google.com/gke-accelerator" = "nvidia-l4"
        }

        container {
          name  = "vllm"
          image = local.image
          args = [
            "--model", "/models/${var.model}",
            "--served-model-name", var.model,
            "--max-model-len", "8192",
          ]

          port {
            container_port = 8000
          }

          resources {
            requests = { cpu = "2", memory = "8Gi" }
            limits   = { "nvidia.com/gpu" = "1" }
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            period_seconds = 10
          }

          volume_mount {
            name       = "models"
            mount_path = "/models"
            read_only  = true
          }
          volume_mount {
            name       = "dshm"
            mount_path = "/dev/shm"
          }
        }

        volume {
          name = "models"
          csi {
            driver    = "gcsfuse.csi.storage.gke.io"
            read_only = true
            volume_attributes = {
              bucketName = "${var.project_id}-models"
            }
          }
        }

        # Shared memory for PyTorch; the container default (64 MB) is too small.
        volume {
          name = "dshm"
          empty_dir {
            medium     = "Memory"
            size_limit = "2Gi"
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "vllm" {
  metadata {
    name      = "vllm"
    namespace = kubernetes_namespace_v1.serving.metadata[0].name
  }

  spec {
    selector = local.labels
    port {
      port        = 8000
      target_port = 8000
    }
  }
}
