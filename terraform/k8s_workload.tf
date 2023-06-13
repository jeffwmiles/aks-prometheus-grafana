## ---------------------------------------------------
# Sample workload installation
## ---------------------------------------------------
resource "kubernetes_namespace" "test" {
  metadata {
    name = "test"
    labels = {
      # Used for akv2k8s integration
      "azure-key-vault-env-injection" = "enabled"
    }
  }
}
resource "kubernetes_deployment_v1" "wintest" {
  metadata {
    namespace = "test"
    name      = "wintest"
    labels = {
      test = "wintest"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        test = "wintest"
      }
    }
    template {
      metadata {
        labels = {
          test = "wintest"
        }
      }
      spec {
        container {
          image = "mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2022"
          name  = "wintest"
        }
      }
    }
  }
}
resource "kubernetes_service_v1" "wintest" {
  metadata {
    namespace = "test"
    name      = "wintest-svc"
  }
  spec {
    selector = {
      test = "wintest"
    }
    port {
      port        = 80
      target_port = 80
    }
  }
}

resource "kubernetes_ingress_v1" "wintest" {
  metadata {
    namespace = "test"
    name      = "wintest-ingress"
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      http {
        path {
          path = "/"
          backend {
            service {
              name = "wintest-svc"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
