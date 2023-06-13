## ---------------------------------------------------
# Managed Prometheus
## ---------------------------------------------------
resource "azurerm_monitor_workspace" "default" {
  name                = "prom-test"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
}
## ---------------------------------------------------
# Managed Grafana
## ---------------------------------------------------
resource "azurerm_dashboard_grafana" "default" {
  name                              = "graf-test"
  resource_group_name               = azurerm_resource_group.default.name
  location                          = azurerm_resource_group.default.location
  api_key_enabled                   = true
  deterministic_outbound_ip_enabled = false
  public_network_access_enabled     = true
  identity {
    type = "SystemAssigned"
  }
  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.default.id
  }
}

# Add required role assignment over resource group containing the Azure Monitor Workspace
resource "azurerm_role_assignment" "grafana" {
  scope                = azurerm_resource_group.default.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.default.identity[0].principal_id
}

# Add role assignment to Grafana so an admin user can log in
resource "azurerm_role_assignment" "grafana-admin" {
  scope                = azurerm_dashboard_grafana.default.id
  role_definition_name = "Grafana Admin"
  principal_id         = var.adminGroupObjectIds[0]
}

# Output the grafana url for usability
output "grafana_url" {
  value = azurerm_dashboard_grafana.default.endpoint
}

## ---------------------------------------------------
# Data Collection resources for Prometheus and Monitor Agent
## ---------------------------------------------------
resource "azurerm_monitor_data_collection_endpoint" "dce" {
  name                = "MSProm-${azurerm_monitor_workspace.default.location}-${azurerm_kubernetes_cluster.default.name}"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_monitor_workspace.default.location
  kind                = "Linux"
}

resource "azurerm_monitor_data_collection_rule" "dcr" {
  name                        = "MSProm-${azurerm_monitor_workspace.default.location}-${azurerm_kubernetes_cluster.default.name}"
  resource_group_name         = azurerm_resource_group.default.name
  location                    = azurerm_monitor_workspace.default.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.dce.id
  kind                        = "Linux"
  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.default.id
      name               = "MonitoringAccount1"
    }
  }
  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount1"]
  }
  data_sources {
    prometheus_forwarder {
      streams = ["Microsoft-PrometheusMetrics"]
      name    = "PrometheusDataSource"
    }
  }
  description = "DCR for Azure Monitor Metrics Profile (Managed Prometheus)"
  depends_on = [
    azurerm_monitor_data_collection_endpoint.dce
  ]
}

resource "azurerm_monitor_data_collection_rule_association" "dcra" {
  name                    = "MSProm-${azurerm_monitor_workspace.default.location}-${azurerm_kubernetes_cluster.default.name}"
  target_resource_id      = azurerm_kubernetes_cluster.default.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr.id
  description             = "Association of data collection rule. Deleting this association will break the data collection for this AKS Cluster."
  depends_on = [
    azurerm_monitor_data_collection_rule.dcr
  ]
}

## ---------------------------------------------------
# Linux Recording Rules
## ---------------------------------------------------
resource "azapi_resource" "NodeRecordingRulesRuleGroup" {
  type      = "Microsoft.AlertsManagement/prometheusRuleGroups@2023-03-01"
  name      = "NodeRecordingRulesRuleGroup-${azurerm_kubernetes_cluster.default.name}"
  location  = azurerm_monitor_workspace.default.location
  parent_id = azurerm_resource_group.default.id
  body = jsonencode({
    "properties" : {
      "scopes" : [
        azurerm_monitor_workspace.default.id
      ],
      "clusterName" : azurerm_kubernetes_cluster.default.name,
      "interval" : "PT1M",
      "rules" : [
        {
          "record" : "instance:node_num_cpu:sum",
          "expression" : "count without (cpu, mode) (  node_cpu_seconds_total{job=\"node\",mode=\"idle\"})"
        },
        {
          "record" : "instance:node_cpu_utilisation:rate5m",
          "expression" : "1 - avg without (cpu) (  sum without (mode) (rate(node_cpu_seconds_total{job=\"node\", mode=~\"idle|iowait|steal\"}[5m])))"
        },
        {
          "record" : "instance:node_load1_per_cpu:ratio",
          "expression" : "(  node_load1{job=\"node\"}/  instance:node_num_cpu:sum{job=\"node\"})"
        },
        {
          "record" : "instance:node_memory_utilisation:ratio",
          "expression" : "1 - (  (    node_memory_MemAvailable_bytes{job=\"node\"}    or    (      node_memory_Buffers_bytes{job=\"node\"}      +      node_memory_Cached_bytes{job=\"node\"}      +      node_memory_MemFree_bytes{job=\"node\"}      +      node_memory_Slab_bytes{job=\"node\"}    )  )/  node_memory_MemTotal_bytes{job=\"node\"})"
        },
        {
          "record" : "instance:node_vmstat_pgmajfault:rate5m",
          "expression" : "rate(node_vmstat_pgmajfault{job=\"node\"}[5m])"
        },
        {
          "record" : "instance_device:node_disk_io_time_seconds:rate5m",
          "expression" : "rate(node_disk_io_time_seconds_total{job=\"node\", device!=\"\"}[5m])"
        },
        {
          "record" : "instance_device:node_disk_io_time_weighted_seconds:rate5m",
          "expression" : "rate(node_disk_io_time_weighted_seconds_total{job=\"node\", device!=\"\"}[5m])"
        },
        {
          "record" : "instance:node_network_receive_bytes_excluding_lo:rate5m",
          "expression" : "sum without (device) (  rate(node_network_receive_bytes_total{job=\"node\", device!=\"lo\"}[5m]))"
        },
        {
          "record" : "instance:node_network_transmit_bytes_excluding_lo:rate5m",
          "expression" : "sum without (device) (  rate(node_network_transmit_bytes_total{job=\"node\", device!=\"lo\"}[5m]))"
        },
        {
          "record" : "instance:node_network_receive_drop_excluding_lo:rate5m",
          "expression" : "sum without (device) (  rate(node_network_receive_drop_total{job=\"node\", device!=\"lo\"}[5m]))"
        },
        {
          "record" : "instance:node_network_transmit_drop_excluding_lo:rate5m",
          "expression" : "sum without (device) (  rate(node_network_transmit_drop_total{job=\"node\", device!=\"lo\"}[5m]))"
        }
      ]
    }
  })

  schema_validation_enabled = false
  ignore_missing_property   = false
}

resource "azapi_resource" "KubernetesReccordingRulesRuleGroup" {
  type      = "Microsoft.AlertsManagement/prometheusRuleGroups@2023-03-01"
  name      = "KubernetesReccordingRulesRuleGroup-${azurerm_kubernetes_cluster.default.name}"
  location  = azurerm_monitor_workspace.default.location
  parent_id = azurerm_resource_group.default.id
  body = jsonencode({
    "properties" : {
      "scopes" : [
        azurerm_monitor_workspace.default.id
      ],
      "clusterName" : azurerm_kubernetes_cluster.default.name,
      "interval" : "PT1M",
      "rules" : [
        {
          "record" : "node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate",
          "expression" : "sum by (cluster, namespace, pod, container) (  irate(container_cpu_usage_seconds_total{job=\"cadvisor\", image!=\"\"}[5m])) * on (cluster, namespace, pod) group_left(node) topk by (cluster, namespace, pod) (  1, max by(cluster, namespace, pod, node) (kube_pod_info{node!=\"\"}))"
        },
        {
          "record" : "node_namespace_pod_container:container_memory_working_set_bytes",
          "expression" : "container_memory_working_set_bytes{job=\"cadvisor\", image!=\"\"}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=\"\"}))"
        },
        {
          "record" : "node_namespace_pod_container:container_memory_rss",
          "expression" : "container_memory_rss{job=\"cadvisor\", image!=\"\"}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=\"\"}))"
        },
        {
          "record" : "node_namespace_pod_container:container_memory_cache",
          "expression" : "container_memory_cache{job=\"cadvisor\", image!=\"\"}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=\"\"}))"
        },
        {
          "record" : "node_namespace_pod_container:container_memory_swap",
          "expression" : "container_memory_swap{job=\"cadvisor\", image!=\"\"}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=\"\"}))"
        },
        {
          "record" : "cluster:namespace:pod_memory:active:kube_pod_container_resource_requests",
          "expression" : "kube_pod_container_resource_requests{resource=\"memory\",job=\"kube-state-metrics\"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) (  (kube_pod_status_phase{phase=~\"Pending|Running\"} == 1))"
        },
        {
          "record" : "namespace_memory:kube_pod_container_resource_requests:sum",
          "expression" : "sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_requests{resource=\"memory\",job=\"kube-state-metrics\"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~\"Pending|Running\"} == 1        )    ))"
        },
        {
          "record" : "cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests",
          "expression" : "kube_pod_container_resource_requests{resource=\"cpu\",job=\"kube-state-metrics\"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) (  (kube_pod_status_phase{phase=~\"Pending|Running\"} == 1))"
        },
        {
          "record" : "namespace_cpu:kube_pod_container_resource_requests:sum",
          "expression" : "sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_requests{resource=\"cpu\",job=\"kube-state-metrics\"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~\"Pending|Running\"} == 1        )    ))"
        },
        {
          "record" : "cluster:namespace:pod_memory:active:kube_pod_container_resource_limits",
          "expression" : "kube_pod_container_resource_limits{resource=\"memory\",job=\"kube-state-metrics\"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) (  (kube_pod_status_phase{phase=~\"Pending|Running\"} == 1))"
        },
        {
          "record" : "namespace_memory:kube_pod_container_resource_limits:sum",
          "expression" : "sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_limits{resource=\"memory\",job=\"kube-state-metrics\"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~\"Pending|Running\"} == 1        )    ))"
        },
        {
          "record" : "cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits",
          "expression" : "kube_pod_container_resource_limits{resource=\"cpu\",job=\"kube-state-metrics\"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ( (kube_pod_status_phase{phase=~\"Pending|Running\"} == 1) )"
        },
        {
          "record" : "namespace_cpu:kube_pod_container_resource_limits:sum",
          "expression" : "sum by (namespace, cluster) (    sum by (namespace, pod, cluster) (        max by (namespace, pod, container, cluster) (          kube_pod_container_resource_limits{resource=\"cpu\",job=\"kube-state-metrics\"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (          kube_pod_status_phase{phase=~\"Pending|Running\"} == 1        )    ))"
        },
        {
          "record" : "namespace_workload_pod:kube_pod_owner:relabel",
          "expression" : "max by (cluster, namespace, workload, pod) (  label_replace(    label_replace(      kube_pod_owner{job=\"kube-state-metrics\", owner_kind=\"ReplicaSet\"},      \"replicaset\", \"$1\", \"owner_name\", \"(.*)\"    ) * on(replicaset, namespace) group_left(owner_name) topk by(replicaset, namespace) (      1, max by (replicaset, namespace, owner_name) (        kube_replicaset_owner{job=\"kube-state-metrics\"}      )    ),    \"workload\", \"$1\", \"owner_name\", \"(.*)\"  ))",
          "labels" : {
            "workload_type" : "deployment"
          }
        },
        {
          "record" : "namespace_workload_pod:kube_pod_owner:relabel",
          "expression" : "max by (cluster, namespace, workload, pod) (  label_replace(    kube_pod_owner{job=\"kube-state-metrics\", owner_kind=\"DaemonSet\"},    \"workload\", \"$1\", \"owner_name\", \"(.*)\"  ))",
          "labels" : {
            "workload_type" : "daemonset"
          }
        },
        {
          "record" : "namespace_workload_pod:kube_pod_owner:relabel",
          "expression" : "max by (cluster, namespace, workload, pod) (  label_replace(    kube_pod_owner{job=\"kube-state-metrics\", owner_kind=\"StatefulSet\"},    \"workload\", \"$1\", \"owner_name\", \"(.*)\"  ))",
          "labels" : {
            "workload_type" : "statefulset"
          }
        },
        {
          "record" : "namespace_workload_pod:kube_pod_owner:relabel",
          "expression" : "max by (cluster, namespace, workload, pod) (  label_replace(    kube_pod_owner{job=\"kube-state-metrics\", owner_kind=\"Job\"},    \"workload\", \"$1\", \"owner_name\", \"(.*)\"  ))",
          "labels" : {
            "workload_type" : "job"
          }
        },
        {
          "record" : ":node_memory_MemAvailable_bytes:sum",
          "expression" : "sum(  node_memory_MemAvailable_bytes{job=\"node\"} or  (    node_memory_Buffers_bytes{job=\"node\"} +    node_memory_Cached_bytes{job=\"node\"} +    node_memory_MemFree_bytes{job=\"node\"} +    node_memory_Slab_bytes{job=\"node\"}  )) by (cluster)"
        },
        {
          "record" : "cluster:node_cpu:ratio_rate5m",
          "expression" : "sum(rate(node_cpu_seconds_total{job=\"node\",mode!=\"idle\",mode!=\"iowait\",mode!=\"steal\"}[5m])) by (cluster) /count(sum(node_cpu_seconds_total{job=\"node\"}) by (cluster, instance, cpu)) by (cluster)"
        }
      ]
    }
  })

  schema_validation_enabled = false
  ignore_missing_property   = false
}
