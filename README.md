# Observability Chart Agent Specification

## Purpose

This repository defines a specification for an LLM agent that dynamically generates modular Helm charts for Kubernetes observability deployments.

The agent must generate an `observability_operator_chart_<suffix>` according to the user's requested telemetry signals.

The generated chart must:
- include only the required observability components based on user-requested signals
- generate a minimal OpenTelemetry Collector configuration
- avoid unused dependencies
- avoid unused scrape jobs
- generate valid Helm templates
- generate valid Kubernetes manifests

---

# High-Level Architecture

The generated chart consists of:
1. A parent Helm chart named `observability_operator`
2. A local sub-chart named `otel_collector`
3. Optional third-party Helm chart dependencies, included only when required by the requested signals

The parent chart is responsible for:
- declaring Helm chart dependencies
- orchestrating exporter installation

The `otel_collector` sub-chart is responsible for:
- OTLP telemetry ingestion
- Prometheus scraping
- telemetry enrichment
- telemetry export

---

# Required Output Structure

```text
observability_operator_chart_<suffix>/
  observability_operator/
    Chart.yaml
    values.yaml
  otel_collector/
    Chart.yaml
    values.yaml
    templates/
      otel-collector.yaml
      permission.yaml
```

**Rules:**
- The parent chart `observability_operator` must contain dependency declarations only in `Chart.yaml`. Its `values.yaml` may contain dependency value overrides where needed (e.g. network-latency target hosts, fluent-bit inputs).
- Always include observability_operator/templates/NOTES.txt with a brief description of the chart. This prevents helm lint from warning about a missing templates/ directory.
- The parent chart must always include the local `otel-collector` sub-chart dependency.
- The `otel_collector` sub-chart is defined only in `otel_collector/`.

---

# User Input Contract

The user provides their requirements in natural language. The agent must extract the following from the user's message:

**Required:**
```yaml
clusterName: ""               # name of the target cluster
otlpExportEndpoint:
  host: ""                    # hostname or IP of the OTLP export destination
  port: 4318                  # port of the OTLP export destination
```

**Optional (use defaults if not specified):**
```yaml
scrapeInterval: 5s
evaluationInterval: 5s
```

**Signals** (derived from natural language — see Signal-to-Dependency Mapping below):
```yaml
signals:
  energy: false
  nodeResources: false
  containerResources: false
  kubernetesState: false
  kubelet: false
  networkLatency: false
  applicationMetrics: false
  applicationLogs: false
  systemLogs: false
  kubernetesEvents: false
  traces: false
```

If a signal is not mentioned by the user, it must not be included. Do not default signals to true.

**Network latency additional input** (required only when `networkLatency: true`):
```yaml
networkLatency:
  targets:
    - cluster: ""
      host_ip: [""]
```

---

# Signal-to-Dependency Mapping

The agent maps user language to signals, then signals to Helm dependencies and OTel receivers/scrape jobs. Only include what the user explicitly requests.

---

## Energy Metrics

**Keywords:** energy metrics, power consumption, node energy, pod energy, container energy, sustainability metrics

**Helm dependency** (parent `Chart.yaml`):
```yaml
- name: kepler
  version: 0.6.1
  repository: "https://sustainable-computing-io.github.io/kepler-helm-chart"
```

**Scrape job** (`otel_collector` prometheus receiver):
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

**Parent `values.yaml` override:**
```yaml
kepler:
  fullnameOverride: kepler
```

---

## Node Resource Metrics

**Keywords:** node CPU usage, node memory usage, filesystem metrics, network device metrics, host-level resource metrics

**Helm dependency** (parent `Chart.yaml`):
```yaml
- name: prometheus-node-exporter
  version: 4.55.0
  repository: "https://prometheus-community.github.io/helm-charts"
```

**Scrape job** (`otel_collector` prometheus receiver):
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

**Parent `values.yaml` override:**
```yaml
prometheus-node-exporter:
  fullnameOverride: node-exporter
```

---

## Kubernetes Object Metrics

**Keywords:** pod status, deployment status, replica counts, Kubernetes object state, desired vs available replicas, namespace-level Kubernetes metadata

**Helm dependency** (parent `Chart.yaml`):
```yaml
- name: kube-state-metrics
  version: 7.4.0
  repository: "https://prometheus-community.github.io/helm-charts"
```

**Scrape job** (`otel_collector` prometheus receiver):
```yaml
- job_name: "kube-state-metrics"
  kubernetes_sd_configs:
    - role: "endpoints"
  relabel_configs:
    - source_labels: [__meta_kubernetes_service_name]
      action: keep
      regex: kube-state-metrics
```

**Parent `values.yaml` override:**
```yaml
kube-state-metrics:
  fullnameOverride: kube-state-metrics
```

---

## Container Resource Metrics

**Keywords:** container CPU usage, container memory usage, container filesystem usage, pod-level resource usage, container-level resource usage

No external Helm dependency required.

**Scrape job** (`otel_collector` prometheus receiver):
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

**Required RBAC resources** (in addition to base RBAC):
```yaml
- nodes/proxy
```

---

## Kubelet Metrics

**Keywords:** kubelet metrics, pod lifecycle metrics, volume metrics, node runtime metrics

No external Helm dependency required.

**Scrape job** (`otel_collector` prometheus receiver):
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

---

## Network Latency Metrics

**Keywords:** network latency, inter-node latency, network delay, connectivity delay metrics

**Helm dependency** (parent `Chart.yaml`):
```yaml
- name: network-latency
  version: 0.1.0
  repository: "https://gitlab.com/api/v4/projects/44429468/packages/helm/stable"
```

**Scrape job** (`otel_collector` prometheus receiver):
```yaml
- job_name: "network-latency-agent"
  kubernetes_sd_configs:
    - role: "service"
  relabel_configs:
    - source_labels: [__meta_kubernetes_service_name]
      action: keep
      regex: network-latency-agent-service
```

**Parent `values.yaml` override** (target hosts come from user input):
```yaml
network-latency:
  target_hosts:
    - cluster: "<user-provided cluster name>"
      host_ip: ["<user-provided IP>"]
```

---

## Application Metrics

**Keywords:** custom metrics, application metrics, OTLP metrics, instrumented metrics

No external Helm dependency required.

Requires the `otlp` receiver in the `otel_collector` sub-chart, included in the metrics pipeline.

---

## Application Logs

**Keywords:** application logs, OTLP logs, instrumented logs

No external Helm dependency required. No Fluent Bit. No log tailing. No systemd or containerd scraping.

Requires the `otlp` receiver in the `otel_collector` sub-chart, included in the logs pipeline.

---

## System Logs

**Keywords:** Kubernetes system logs, kubelet logs, node logs, cluster logs, system logs, containerd logs, non-application logs, journald logs

**Helm dependency** (parent `Chart.yaml`):
```yaml
- name: fluent-bit
  version: 0.57.6
  repository: "https://fluent.github.io/helm-charts"
```

**Parent `values.yaml` override** (Fluent Bit must be configured with inputs and outputs):
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

## Kubernetes Events Logs

**Keywords:** Kubernetes events, cluster events, k8s events logs

No external Helm dependency required.

Requires the `k8s_events` receiver in the `otel_collector` sub-chart, included in the logs pipeline:
```yaml
receivers:
  k8s_events:
    auth_type: serviceAccount
    namespaces: []
```

---

# Parent Chart Generation Rules

The parent chart `observability_operator` must always include the local sub-chart dependency:
```yaml
- name: otel-collector
  version: 0.1.0
  repository: "file://../otel_collector"
```

**Rules:**
- Include only the dependencies required by the user-requested signals.
- Do not include any dependency that was not triggered by a signal.
- For each included dependency, add its `fullnameOverride` in the parent `values.yaml` to ensure predictable service discovery names for scrape jobs.

---

# OpenTelemetry Collector Generation Rules

## Always Include

Health check extension:
```yaml
extensions:
  health_check:
    endpoint: 0.0.0.0:13133
```

Container args pointing to the config file:
```yaml
args: ["--config=/conf/otel-agent-config.yaml"]
```

The config file name in the args must match the key used inside the ConfigMap.

---

## Required Processors

Always include both:
```yaml
processors:
  batch:

  resource:
    attributes:
      - key: cluster
        value: {{ .Values.otelCollector.clusterName }}
        action: insert
```

---

## OTLP Exporter

Always include:
```yaml
exporters:
  otlp:
    endpoint: {{ .Values.otelCollector.exporters.otlp.host }}:{{ .Values.otelCollector.exporters.otlp.port }}
    tls:
      insecure: {{ .Values.otelCollector.exporters.otlp.tls.insecure | default true }}
```

---

## OTLP Receiver

Include only when application traces, application OTLP metrics, or application OTLP logs are requested:
```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
```

---

## Kubernetes Events Receiver

Include only when Kubernetes events logs are requested:
```yaml
receivers:
  k8s_events:
    auth_type: serviceAccount
    namespaces: []
```

---

## Prometheus Receiver

Include only when at least one Prometheus-compatible scrape job is needed (kepler, node-exporter, cadvisor, kubelet, kube-state-metrics, network-latency):
```yaml
receivers:
  prometheus:
    config:
      global:
        scrape_interval: {{ .Values.otelCollector.scrapeInterval }}
        evaluation_interval: {{ .Values.otelCollector.evaluationInterval }}
      scrape_configs:
        # include only the scrape jobs for requested signals
```

---

# Pipeline Generation Rules

Generate only the pipelines required by the requested signals. Each pipeline must reference only receivers, processors, and exporters that are defined in the configuration.

**Metrics pipeline** — include when any metrics signal is requested:
```yaml
metrics:
  receivers: [<only the ones defined>]
  processors: [resource, batch]
  exporters: [otlp]
```

**Traces pipeline** — include only when traces are requested:
```yaml
traces:
  receivers: [otlp]
  processors: [resource, batch]
  exporters: [otlp]
```

**Logs pipeline** — include when any log signal is requested:
```yaml
logs:
  receivers: [<only the ones defined>]
  processors: [resource, batch]
  exporters: [otlp]
```

**Consistency rules:**
- A pipeline must not reference a receiver that is not defined.
- A pipeline must not reference a processor that is not defined.
- Every defined receiver must appear in at least one pipeline.

---

# Helm Templating Rules

## Values Namespace

All collector configuration must be nested under:
```yaml
otelCollector:
```

## Prometheus Relabel Escaping

Inside Helm templates, use `$${1}` not `${1}`:
```yaml
replacement: "/api/v1/nodes/$${1}/proxy/metrics/cadvisor"
```

## Namespace References

Use `{{ .Release.Namespace }}` in ClusterRoleBindings:
```yaml
namespace: {{ .Release.Namespace }}
```

## Collector Ports

Expose only the ports required by the included receivers:

OTLP gRPC (include when `otlp` receiver is defined):
```yaml
otlp-grpc:
  port: 4317
  targetPort: 4317
```

OTLP HTTP (include when `otlp` receiver is defined):
```yaml
otlp-http:
  port: 4318
  targetPort: 4318
```

---

# RBAC Rules

Always include base RBAC in `permission.yaml`:
```yaml
resources:
  - pods
  - nodes
  - services
  - endpoints
  - events
```

Add `nodes/proxy` when cadvisor or kubelet scrape jobs are included.

---

# Reference Chart

The repository includes a working example chart at `reference-chart/`.

**The reference chart demonstrates the maximum possible configuration** — all signals enabled. The agent must not copy it wholesale. Use it only as a style reference for:
- Helm template syntax and structure
- ConfigMap, Deployment, and Service manifest layout
- RBAC manifest structure
- Templating conventions (`{{ .Values... }}`, `{{- range ... }}`, `$${1}` escaping)

The agent must generate a minimal chart driven by the user's requested signals, not reproduce the reference chart.
