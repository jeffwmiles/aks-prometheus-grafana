## ---------------------------------------------------
# Grafana Dashboards
## ---------------------------------------------------
resource "grafana_dashboard" "nginxmetrics" {
  depends_on = [ azurerm_dashboard_grafana.default ]
  config_json = file("nginx.json")
}
resource "grafana_dashboard" "requestHandlingPerformance" {
  depends_on = [ azurerm_dashboard_grafana.default ]
  config_json = file("requestHandlingPerformance.json")
}
