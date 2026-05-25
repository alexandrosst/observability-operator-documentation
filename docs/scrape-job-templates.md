# Prometheus Scrape Job Templates
The agent must use these exact scrape job templates when generating the Collector Prometheus receiver.

## Kepler

```yaml
- job_name: "kepler"
  kubernetes_sd_configs:
    - role: "pod"
  relabel_configs:
    - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
      regex: "kepler"
      action: "keep"
    - source_labels: [__meta_kubernetes_pod_node_name]
      target_label: node
```

## Node Exporter

```yaml
- job_name: "node-exporter"
  kubernetes_sd_configs:
    - role: "pod"
  relabel_configs:
    - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
      regex: "prometheus-node-exporter"
      action: "keep"
    - source_labels: [__meta_kubernetes_pod_node_name]
      target_label: node
```

## cAdvisor

```yaml
- job_name: "cadvisor"
  scheme: "https"
  tls_config:
    ca_file: "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
  bearer_token_file: "/var/run/secrets/kubernetes.io/serviceaccount/token"
  kubernetes_sd_configs:
    - role: "node"
  relabel_configs:
    - target_label: "__address__"
      replacement: "kubernetes.default.svc:443"
      action: "replace"
    - source_labels: [__meta_kubernetes_node_name]
      regex: "(.+)"
      target_label: "__metrics_path__"
      replacement: "/api/v1/nodes/$${1}/proxy/metrics/cadvisor"
      action: "replace"
```

## Kubelet

```yaml
- job_name: "kubelet"
  scheme: "https"
  tls_config:
    ca_file: "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
  bearer_token_file: "/var/run/secrets/kubernetes.io/serviceaccount/token"
  kubernetes_sd_configs:
    - role: "node"
  relabel_configs:
    - target_label: "__address__"
      replacement: "kubernetes.default.svc:443"
      action: "replace"
    - source_labels: [__meta_kubernetes_node_name]
      regex: "(.+)"
      target_label: "__metrics_path__"
      replacement: "/api/v1/nodes/$${1}/proxy/metrics"
      action: "replace"
```

## kube-state-metrics

```yaml
- job_name: "kube-state-metrics"
  kubernetes_sd_configs:
    - role: "endpoints"
  relabel_configs:
    - source_labels: [__meta_kubernetes_service_name]
      action: keep
      regex: kube-state-metrics
```

## Network Latency Exporter

```yaml
- job_name: "network-latency-agent"
  kubernetes_sd_configs:
    - role: "service"
  relabel_configs:
    - source_labels: [__meta_kubernetes_service_name]
      action: keep
      regex: network-latency-agent-service
```