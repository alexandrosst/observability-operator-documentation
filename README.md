# Observability Chart Agent Specification
## Purpose
This repository defines a specification for an LLM agent that dynamically generates modular Helm charts for Kubernetes observability deployments.

The agent must generate an `observability_operator_chart_<suffix>` according to the user's requested telemetry signals.

The generated chart should:
- include only the required observability components,
- generate a minimal OpenTelemetry Collector configuration,
- avoid unused dependencies,
- avoid unused scrape jobs,
- generate valid Helm templates,
- generate valid Kubernetes manifests.

This specification is intended to reduce unnecessary tool calls and provide a single authoritative source for chart generation.

---

# High-Level Architecture

The generated chart consists of:
1. A parent Helm chart named `observability-operator`
2. A local sub-chart named `otel-collector`
3. Optional third-party Helm chart dependencies

The parent chart is responsible for:
* declaring Helm dependencies,
* orchestrating exporter installation.

The `otel-collector` sub-chart is responsible for:
* OTLP telemetry ingestion,
* Prometheus scraping,
* telemetry enrichment,
* telemetry export.

---

# Required Output Structure

The agent must generate the following structure.

```text
observability_operator_chart/
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

Rules:

* Collector manifests must exist only inside:

```text
otel_collector/templates/
```

* The parent chart must contain dependency declarations only.

* The parent chart must always include the local `otel-collector` dependency.

---

# User Input Contract

The user must provide:

```yaml
clusterName: ""
otlpExportEndpoint:
  host: ""
  port: 4318
  protocol: http

tls:
  insecure: true
```

Requested telemetry signals:

```yaml
signals:
  energy: true
  nodeResources: true
  containerResources: true
  kubernetesState: true
  kubelet: true
  networkLatency: true
  logs: true
  traces: true
```

Optional collector configuration:

```yaml
collector:
  image:
    registry: otel
    name: opentelemetry-collector
    tag: latest

  replicas: 1

  scrapeInterval: 5s
  evaluationInterval: 5s

  deploymentName: otel-collector
  serviceName: otel-collector-service
  configMapName: otel-collector-config-map
```

If optional inputs are not provided, the agent should use the defaults above.

---

# Signal-to-Dependency Mapping

The agent must map user telemetry requirements to Helm dependencies.

## Energy Metrics

Keywords:

* energy metrics
* power consumption
* node energy
* pod energy
* container energy
* sustainability metrics

Dependency:

```yaml
- name: kepler
  version: 0.6.1
  repository: "https://sustainable-computing-io.github.io/kepler-helm-chart"
```

Collector scrape job:

```yaml
job_name: "kepler"
```

---

## Node Resource Metrics

Keywords:

* node CPU usage
* node memory usage
* filesystem metrics
* network device metrics
* host-level resource metrics

Dependency:

```yaml
- name: prometheus-node-exporter
  version: 4.55.0
  repository: "https://prometheus-community.github.io/helm-charts"
```

Collector scrape job:

```yaml
job_name: "node-exporter"
```

---

## Kubernetes Object Metrics

Keywords:

* pod status
* deployment status
* replica counts
* Kubernetes object state
* desired vs available replicas
* namespace-level Kubernetes metadata

Dependency:

```yaml
- name: kube-state-metrics
  version: 7.3.0
  repository: "https://prometheus-community.github.io/helm-charts"
```

Collector scrape job:

```yaml
job_name: "kube-state-metrics"
```

---

## Container Resource Metrics

Keywords:

* container CPU usage
* container memory usage
* container filesystem usage
* pod-level resource usage
* container-level resource usage

No external Helm dependency is required.

Collector scrape job:

```yaml
job_name: "cadvisor"
```

Required RBAC:

```yaml
resources:
  - nodes
  - nodes/proxy
```

---

## Kubelet Metrics

Keywords:

* kubelet metrics
* pod lifecycle metrics
* volume metrics
* node runtime metrics

No external Helm dependency is required.

Collector scrape job:

```yaml
job_name: "kubelet"
```

---

## Network Latency Metrics

Keywords:

* network latency
* inter-node latency
* network delay
* connectivity delay metrics

Dependency:

```yaml
- name: network_latency
  alias: network-metrics-exporter
  version: 0.1.0
  repository: "https://gitlab.com/api/v4/projects/44429468/packages/helm/stable"
```


Collector scrape job:

```yaml
job_name: "network-latency-agent"
```

---

## Logs

Keywords:

* container logs
* pod logs
* Kubernetes logs
* node logs

Dependency:

```yaml
- name: fluent-bit
  version: 0.57.6
  repository: "https://fluent.github.io/helm-charts"
```

Logs pipeline should exist only when logs are requested.

---

# Parent Chart Generation Rules

The parent chart must always include:

```yaml
- name: otel-collector
  version: 0.1.0
  repository: "file://../otel_collector"
```

The agent must include only the dependencies required by the selected signals.

The agent must not include unnecessary dependencies.

The agent must not generate enable/disable flags unless required by external charts.

Incorrect:

```yaml
kepler:
  enabled: true
```

Correct:

Only include the dependency when needed.

For each dependency name defined in the parent chart, we can override some of its values by using its name.

---

# OpenTelemetry Collector Generation Rules

The agent must generate the Collector dynamically.

---

## Always Include

```yaml
extensions:
  health_check:
    endpoint: 0.0.0.0:13133
```

and:

```yaml
args: ["--config=/conf/<config-file-name>.yaml"]
```
specifying the otel configuration file name.

---

## Required Processors

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

```yaml
exporters:
  otlp:
    endpoint: {{ .Values.otelCollector.exporters.otlp.host }}:{{ .Values.otelCollector.exporters.otlp.port }}
    tls:
      insecure: {{ .Values.otelCollector.exporters.tls.insecure }}
```

---

## OTLP Receiver

Include the OTLP receiver only when:

* traces are requested,
* OTLP metrics are requested,
* logs are requested.

Template:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

---

# Reference-chart and LLM clarifications

- **Reference chart purpose:** The `reference-chart/` directory is a full, illustrative Helm chart example. It demonstrates a complete chart output; the agent's generated chart for a user request should be minimal and include only the dependencies required by the requested `signals`.

- **Values mapping (explicit):**
  - User input `otlpExportEndpoint.host` → `otelCollector.exporters.otlp.host`
  - User input `otlpExportEndpoint.port` → `otelCollector.exporters.otlp.port`
  - User input `tls.insecure` → `otelCollector.exporters.tls.insecure`
  - If the user supplies top-level fields, the agent MUST map them into `otelCollector.*` according to the above.

- **Chart folder vs chart name:** When declaring a local chart dependency use the folder path `file://../otel_collector` and ensure the dependency's `name` in `Chart.yaml` matches the folder or that the dependency reference uses the folder path. Agents should prefer matching folder and chart name to avoid ambiguity.

- **Network metrics (explicit guidance):**
  - Signal: `networkLatency` maps to the external Helm chart:
    - name: `network_latency`
    - alias: `network-metrics-exporter`
  - Values for the aliased chart must be provided under the alias key in `values.yaml`:

    ```yaml
    network-metrics-exporter:
      target_hosts:
        - cluster: example
          host_ip: ["10.0.0.1"]
    ```

  - Collector scrape job name: `network-latency-agent`. If the dependency is present, the agent must add a scrape job that points to the exporter service created by that chart or to configured `target_hosts` via `static_configs`.

- **Container/cadvisor and Kubelet:**
  - `containerResources` → `cadvisor` scrape job. `cadvisor` typically runs as a DaemonSet and requires node-level access.
  - Minimal RBAC example for scraping node/cadvisor and kubelet:

    ```yaml
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRole
    metadata:
      name: observability-scrape
    rules:
      - apiGroups: [""]
        resources: ["nodes", "nodes/proxy"]
        verbs: ["get", "list", "watch", "proxy"]
    ```

- **Alias → values-key resolution:** When a dependency uses `alias`, use the alias as the top-level key in `values.yaml` to override chart values (see `network-metrics-exporter` example).

- **Config filename mapping:** Use `configMapName` to build the file name passed to the collector `--config` arg. Example: if `configMapName: otel-collector-config-map` then `args: ["--config=/conf/otel-collector-config-map.yaml"]`.

This section is intended to help deterministic agent behavior and remove common ambiguities (network metrics and alias/value mapping are common failure modes).
```

---

## Prometheus Receiver

Include the Prometheus receiver only when Prometheus-compatible exporters are requested.

Template:

```yaml
receivers:
  prometheus:
    config:
      global:
        scrape_interval: {{ .Values.otelCollector.scrapeInterval }}
        evaluation_interval: {{ .Values.otelCollector.evaluationInterval }}
      scrape_configs:
```

---

# Scrape Job Templates

The agent must use the following exact scrape-job templates.

The agent must not invent alternative discovery rules unless the user explicitly changes service names or labels.

---

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

---

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

In the parent chart, we can override its name.

---

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

---

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

---

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

In the parent chart, we can override its name.

---

## Network Metrics Exporter

```yaml
- job_name: "network-metrics-exporter"
  kubernetes_sd_configs:
    - role: "service"
  relabel_configs:
    - source_labels: [__meta_kubernetes_service_name]
      action: keep
      regex: network-latency-agent-service
```

In the parent chart, we can override the target hosts by defining a cluster and its IPs.

---

# Pipeline Generation Rules

Generate only the required pipelines.

---

## Metrics Only

```yaml
service:
  pipelines:
    metrics:
```

---

## Traces

```yaml
service:
  pipelines:
    traces:
```

---

## Logs

```yaml
service:
  pipelines:
    logs:
```

---

## Receiver Consistency

If a pipeline references:

```yaml
prometheus
```

then the Prometheus receiver must exist.

If a pipeline references:

```yaml
otlp
```

then the OTLP receiver must exist.

---

## Processor Consistency

If a pipeline references:

```yaml
resource
batch
```

then these processors must exist.

---

## Exporter Consistency

If a pipeline references:

```yaml
otlp
```

then the OTLP exporter must exist.

---

# Helm Templating Rules

---

## Values Namespace

All Collector configuration must exist under:

```yaml
otelCollector:
```

Example:

```yaml
otelCollector:
  clusterName: my-cluster
  deploymentName: otel-collector
  replicas: 1
```

---

## Prometheus Relabel Escaping

Use:

```yaml
$${1}
```

inside Helm templates.

Incorrect:

```yaml
${1}
```

---

## Namespace References

Use:

```yaml
namespace: {{ .Release.Namespace }}
```

inside ClusterRoleBindings.

---

## Collector Ports

Expose only required ports.

OTLP HTTP:

```yaml
port: 4318
targetPort: 4318
```

OTLP gRPC:

```yaml
port: 4317
targetPort: 4317
```

---

# RBAC Rules

Required RBAC:

```yaml
resources:
  - pods
  - nodes
  - nodes/proxy
  - services
  - endpoints
```

---

# Validation Checklist

The generated chart must satisfy all conditions below.

## Parent Chart

* `observability_operator/Chart.yaml` exists
* chart name is `observability-operator`
* `otel-collector` dependency always exists
* only requested dependencies are included
* no unused dependencies exist

---

## Collector Chart

Required files:

```text
otel_collector/
  Chart.yaml
  values.yaml
  templates/
    otel-collector.yaml
    permission.yaml
```

---

## Collector Configuration

* only required receivers exist
* Prometheus receiver exists only when scrape jobs exist
* each dependency has a matching scrape job
* omitted dependencies must not have scrape jobs
* OTLP exporter endpoint comes from user input
* cluster resource attribute exists

---

## Helm Validation

The generated chart must pass:

```bash
helm lint observability_operator_chart/observability_operator
```

and:

```bash
helm template observability_operator_chart/observability_operator
```

without errors.

---

# Reference Chart

The repository may also include a:

```text
reference-chart/
```

directory.

The reference chart is an example implementation only.

The agent must not blindly copy all dependencies or scrape jobs from the reference chart.

The agent must dynamically generate a minimal chart according to the requested signals.

The reference chart exists to:

* demonstrate Helm style,
* demonstrate templating conventions,
* demonstrate Collector configuration structure,
* demonstrate RBAC structure.

---

# Reference Chart Files

## reference-chart/observability_operator/Chart.yaml

```yaml
apiVersion: v2
name: observability-operator
description: A Helm chart for deploying observability components.
type: application
version: 0.1.0
appVersion: dev

dependencies:
  - name: otel-collector
    version: 0.1.0
    repository: "file://../otel_collector"
```

---

## reference-chart/otel_collector/Chart.yaml

```yaml
apiVersion: v2
name: otel-collector
description: A Helm chart for deploying an OpenTelemetry Collector.
type: application
version: 0.1.0
appVersion: dev
```

---

## reference-chart/otel_collector/values.yaml

```yaml
otelCollector:
  clusterName: demo-cluster

  deploymentName: otel-collector
  replicas: 1

  configMapName: otel-collector-config-map
  serviceName: otel-collector-service

  image:
    registry: otel
    name: opentelemetry-collector
    tag: latest

  scrapeInterval: 5s
  evaluationInterval: 5s

  exporters:
    otlp:
      host: observability-backend.default.svc.cluster.local
      port: 4318

    tls:
      insecure: true
```

---

## reference-chart/otel_collector/templates/permission.yaml

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: otel-collector-serviceaccount
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: otel-collector-clusterrole
rules:
- apiGroups: [""]
  resources:
  - pods
  - nodes
  - nodes/proxy
  - services
  - endpoints
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: otel-collector-clusterrolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: otel-collector-clusterrole
subjects:
- kind: ServiceAccount
  name: otel-collector-serviceaccount
  namespace: {{ .Release.Namespace }}
```
