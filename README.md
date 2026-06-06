# Observability Chart Agent Specification

## Purpose

This repository defines a specification for an LLM agent that dynamically generates modular Helm charts for Kubernetes observability deployments.

The agent generates an `observability_operator_chart_<clusterName>` directory containing only the components required by the user's requested telemetry signals. No unused dependencies, no unused scrape jobs.

---

# Required Output Structure

```text
observability_operator_chart_<clusterName>/
  observability_operator/
    Chart.yaml
    values.yaml
    templates/
      NOTES.txt          ← always required (helm lint --strict fails without it)
  otel_collector/
    Chart.yaml
    values.yaml
    templates/
      otel-collector.yaml
      permission.yaml
```

---

# User Input Contract

**Required:**
- `clusterName` — name of the target cluster
- `otlpExportEndpoint.host` — hostname or IP of the OTLP export destination

**Optional (defaults):**
- `otlpExportEndpoint.port` — default `4318`
- `scrapeInterval` — default `5s`
- `evaluationInterval` — default `5s`

**Signals** (all default to false; only set true when explicitly requested):

| Signal | Keywords |
|---|---|
| `energy` | energy metrics, power consumption, node energy, pod energy, sustainability |
| `nodeResources` | node CPU, node memory, filesystem metrics, host-level resource metrics |
| `containerResources` | container CPU, container memory, pod-level resource usage |
| `kubernetesState` | pod status, deployment status, replica counts, Kubernetes object state |
| `kubelet` | kubelet metrics, pod lifecycle metrics, volume metrics, node runtime metrics |
| `networkLatency` | network latency, inter-node latency, network delay |
| `applicationMetrics` | custom metrics, OTLP metrics, instrumented metrics |
| `applicationLogs` | application logs, OTLP logs, instrumented logs |
| `systemLogs` | system logs, kubelet logs, node logs, containerd logs, journald logs |
| `kubernetesEvents` | Kubernetes events, cluster events, k8s events |
| `traces` | traces, distributed tracing, spans |

**Network latency additional input** (required only when `networkLatency: true`):
```yaml
networkLatency:
  targets:
    - cluster: "<user-provided cluster name>"
      host_ip: ["<user-provided IP>"]
```

---

# Signal-to-Component Mapping

| Signal | Helm dependency | Scrape job | OTel receiver |
|---|---|---|---|
| `energy` | `kepler` | `kepler` | `prometheus` |
| `nodeResources` | `prometheus-node-exporter` | `node-exporter` | `prometheus` |
| `containerResources` | — | `cadvisor` | `prometheus` |
| `kubernetesState` | `kube-state-metrics` | `kube-state-metrics` | `prometheus` |
| `kubelet` | — | `kubelet` | `prometheus` |
| `networkLatency` | `network-latency` | `network-latency-agent` | `prometheus` |
| `applicationMetrics` | — | — | `otlp` |
| `applicationLogs` | — | — | `otlp` |
| `systemLogs` | `fluent-bit` | — | — |
| `kubernetesEvents` | — | — | `k8s_events` |
| `traces` | — | — | `otlp` |

**RBAC:** add `nodes/proxy` to ClusterRole when `containerResources` or `kubelet` is requested.

---

# Helm Dependency Versions

| Dependency | Version | Repository |
|---|---|---|
| `kepler` | `0.6.1` | `https://sustainable-computing-io.github.io/kepler-helm-chart` |
| `prometheus-node-exporter` | `4.55.0` | `https://prometheus-community.github.io/helm-charts` |
| `kube-state-metrics` | `7.4.0` | `https://prometheus-community.github.io/helm-charts` |
| `network-latency` | `0.1.0` | `https://gitlab.com/api/v4/projects/44429468/packages/helm/stable` |
| `fluent-bit` | `0.57.6` | `https://fluent.github.io/helm-charts` |

The parent chart always includes the local sub-chart:
```yaml
- name: otel-collector
  version: 0.1.0
  repository: "file://../otel_collector"
```

---

# Canonical File Templates

Copy these templates exactly. Fill in only the values from user input. Do not add or remove keys.

---

## observability_operator/Chart.yaml

```yaml
apiVersion: v2
name: observability_operator
description: Observability Operator for <clusterName>
type: application
version: 0.1.0
dependencies:
  - name: otel-collector
    version: 0.1.0
    repository: "file://../otel_collector"
  # add signal-required dependencies here
```

## observability_operator/values.yaml

```yaml
# fullnameOverride for each included dependency (ensures predictable service names)
# Only include keys for dependencies that are actually in Chart.yaml

# kepler:
#   fullnameOverride: kepler

# prometheus-node-exporter:
#   fullnameOverride: node-exporter

# kube-state-metrics:
#   fullnameOverride: kube-state-metrics

# network-latency:
#   target_hosts:
#     - cluster: "<clusterName>"
#       host_ip: ["<IP>"]

# fluent-bit:                    (see Fluent Bit config section below)
#   fullnameOverride: fluent-bit
#   ...
```

## observability_operator/templates/NOTES.txt

```
Observability Operator deployed to cluster {{ .Values.otelCollector.clusterName }}.
```

---

## otel_collector/Chart.yaml

```yaml
apiVersion: v2
name: otel-collector
description: OpenTelemetry Collector sub-chart
type: application
version: 0.1.0
```

## otel_collector/values.yaml

Copy this template exactly. Fill in `host`, `port`, `clusterName`, `scrapeInterval`, `evaluationInterval` from user input. Do not omit any key — missing keys cause nil pointer errors in Helm templates.

```yaml
otelCollector:
  clusterName: ""
  scrapeInterval: 5s
  evaluationInterval: 5s
  exporters:
    otlp:
      host: ""
      port: 4318
      tls:
        insecure: true    # must be defined here — do NOT use | default true in the template
  configMapName: otel-collector-config
  deploymentName: otel-collector
  serviceName: otel-collector
  replicas: 1
  image:
    registry: otel
    name: opentelemetry-collector-contrib
    tag: "0.98.0"
```

---

# Scrape Job Templates

Include only the jobs for requested signals.

## kepler (`energy`)
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

## node-exporter (`nodeResources`)
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

## cadvisor (`containerResources`)
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

## kube-state-metrics (`kubernetesState`)
```yaml
- job_name: "kube-state-metrics"
  kubernetes_sd_configs:
    - role: "endpoints"
  relabel_configs:
    - source_labels: [__meta_kubernetes_service_name]
      action: keep
      regex: kube-state-metrics
```

## kubelet (`kubelet`)
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

## network-latency-agent (`networkLatency`)
```yaml
- job_name: "network-latency-agent"
  kubernetes_sd_configs:
    - role: "service"
  relabel_configs:
    - source_labels: [__meta_kubernetes_service_name]
      action: keep
      regex: network-latency-agent-service
```

---

# OTel Collector ConfigMap Structure

Always include `health_check`, `batch`, `resource`, and `otlp` exporter.
Include receivers and pipelines only for requested signals.

```yaml
extensions:
  health_check:
    endpoint: 0.0.0.0:13133

receivers:
  # prometheus: include if any scrape signal is requested
  #   config:
  #     global:
  #       scrape_interval: {{ .Values.otelCollector.scrapeInterval }}
  #       evaluation_interval: {{ .Values.otelCollector.evaluationInterval }}
  #     scrape_configs:
  #       <include only jobs for requested signals>

  # otlp: include if applicationMetrics, applicationLogs, or traces requested
  #   protocols:
  #     grpc:
  #       endpoint: 0.0.0.0:4317
  #     http:
  #       endpoint: 0.0.0.0:4318

  # k8s_events: include only if kubernetesEvents requested
  #   auth_type: serviceAccount
  #   namespaces: []

processors:
  batch:
  resource:
    attributes:
      - key: cluster
        value: {{ .Values.otelCollector.clusterName }}
        action: insert

exporters:
  otlp:
    endpoint: {{ .Values.otelCollector.exporters.otlp.host }}:{{ .Values.otelCollector.exporters.otlp.port }}
    tls:
      insecure: {{ .Values.otelCollector.exporters.otlp.tls.insecure }}

service:
  extensions: [health_check]
  pipelines:
    # metrics: include when any metrics signal requested
    #   receivers: [<prometheus and/or otlp>]
    #   processors: [resource, batch]
    #   exporters: [otlp]

    # logs: include when applicationLogs, systemLogs, or kubernetesEvents requested
    #   receivers: [<otlp and/or k8s_events>]
    #   processors: [resource, batch]
    #   exporters: [otlp]

    # traces: include only when traces requested
    #   receivers: [otlp]
    #   processors: [resource, batch]
    #   exporters: [otlp]
```

**Pipeline rules:**
- Every defined receiver must appear in exactly one pipeline.
- A pipeline must not reference a receiver that is not defined.
- `systemLogs` sends via Fluent Bit → OTel HTTP, so it does NOT add a receiver to the OTel config.

---

# Collector Ports (Service)

Expose only ports for included receivers:

| Receiver | Port name | Port |
|---|---|---|
| `otlp` (gRPC) | `otlp-grpc` | 4317 |
| `otlp` (HTTP) | `otlp-http` | 4318 |

Do not expose ports if the `otlp` receiver is not included.

---

# Helm Templating Rules

- Use `$${1}` not `${1}` in Prometheus relabel replacement values.
- Use `{{ .Release.Namespace }}` in ClusterRoleBinding subjects.
- Container args must reference the ConfigMap key: `args: ["--config=/conf/otel-agent-config.yaml"]`
- The ConfigMap data key must match the args value (`otel-agent-config.yaml`).

---

# RBAC Rules

Base ClusterRole resources (always include):
```yaml
resources: [pods, nodes, services, endpoints, events]
```

Add `nodes/proxy` when `containerResources` or `kubelet` is requested.

---

# Fluent Bit Configuration (`systemLogs`)

```yaml
fluent-bit:
  fullnameOverride: fluent-bit
  extraVolumes:
    - name: systemd-journal
      hostPath:
        path: /run/systemd/journal
  extraVolumeMounts:
    - name: systemd-journal
      mountPath: /run/systemd/journal
      readOnly: true
  config:
    inputs: |
      [INPUT]
          Name           tail
          Tag            k3s.*
          Path           /var/log/k3s.log
      [INPUT]
          Name           tail
          Tag            syslog.*
          Path           /var/log/syslog
      [INPUT]
          Name           systemd
          Tag            node.system.*
          Path           /run/systemd/journal
          Systemd_Filter _SYSTEMD_UNIT=containerd
    filters: |
      [FILTER]
          Name          modify
          Match         k3s.*
          Add           log_source k3s
          Add           service_name k3s-cluster
      [FILTER]
          Name          modify
          Match         syslog.*
          Add           log_source syslog
          Add           service_name os-systemd
      [FILTER]
          Name          modify
          Match         node.system.*
          Add           log_source containerd
          Add           service_name container-runtime
    outputs: |
      [OUTPUT]
          Name            opentelemetry
          Match           *
          Host            {{ .Values.otelCollector.serviceName }}
          Port            4318
          Logs_URI        /v1/logs
          Tls             Off
          Logs_body_key   log
          Logs_body_key_attributes true
          Logs_attributes_metadata_key attributes
          Logs_resource_metadata_key resource
          Logs_instrumentation_scope_metadata_key scope
```

---

# Reference Chart

The repository includes a working example at `reference-chart/`. It is the **maximum configuration** with all signals enabled. Use it only as a style reference for Helm template syntax, manifest structure, and templating conventions. Do not copy its dependencies or scrape jobs — generate only what the user requested.
