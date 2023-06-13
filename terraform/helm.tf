## ---------------------------------------------------
# Helm Install
## ---------------------------------------------------
resource "helm_release" "akv2k8s" {
  name              = "akv2k8s"
  chart             = "third-party-helm/akv2k8s"
  namespace         = "akv2k8s"
  version           = "2.3.2"
  create_namespace  = true
  dependency_update = true
  set {
    name  = "controller.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }
  set {
    name  = "env_injector.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }
  set {
    name  = "global.metrics.enabled"
    value = "true"
  }
}

resource "helm_release" "ingress-nginx" {
  name              = "ingress-nginx"
  chart             = "third-party-helm/ingress-nginx"
  namespace         = "ingress-nginx"
  version           = "4.7.0"
  create_namespace  = true
  dependency_update = true
  set {
    name  = "controller.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }
  set {
    name  = "metrics.enabled"
    value = "true"
  }
  set {
    name  = "controller.podAnnotations.prometheus\\.io/scrape"
    value = "true"
  }
  #set {
  #  name  = "controller.podAnnotations.prometheus\\.io/port"
  #  value = "10254"
  #}
}
