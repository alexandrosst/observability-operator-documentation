# Observability Chart Agent Specification
## Purpose
This repository defines a specification for an LLM agent that dynamically generates modular Helm charts for Kubernetes observability deployments.

The agent must generate an `observability_operator_chart_<suffix>` according to the user's requested telemetry signals.

The generated chart should:
- include only the required observability components,
- generate a minimal OpenTelemetry Collector configuration,
- avoid unused dependencies,
- avoid unused scrape jobs,
- generate valid helm templates,
- generate valid Kubernetes manifests.

---

# High-Level Architecture
The generated chart consists of:
1. A parent helm chart named `observability_operator`
2. A local sub-chart named `otel_collector`
3. Optional third-party helm chart dependencies

The parent chart is responsible for:
* declaring helm chart dependencies,
* orchestrating exporter installation.

The `otel_collector` sub-chart is responsible for:
* OTLP telemetry ingestion,
* Prometheus scraping,
* telemetry enrichment,
* telemetry export.

---

# Required Output Structure
The agent must generate the following structure.
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
- The parent chart `observability_operator` must contain dependency declarations only in `Chart.yaml`. In its `values.yaml` file it can contain overrides for its dependencies values if needed, like with network-latency or fluent-bit.
- The parent chart must always include the local sub-chart `otel-collector` dependency.
- `otel_collector` sub-chart is defined only in `otel_collector/`.

---

# User Input Contract
The user must provide configuration for `otel_collector` sub-chart:
```yaml
clusterName: ""
otlpExportEndpoint:
  ip: ""
  port: 4318
```

The user may also request telemetry signals, such as:
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

The user may also provide the srcape interval for metrics `scrapeInterval`.

Some optional otel collector configuration is the following:
```yaml
collector:
  image:
    registry: otel
    name: opentelemetry-collector-contrib
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
- energy metrics
- power consumption
- node energy
- pod energy
- container energy
- sustainability metrics

Dependency to be added in the parent `observability_operator` chart:
```yaml
- name: kepler
  version: 0.6.1
  repository: "https://sustainable-computing-io.github.io/kepler-helm-chart"
```

Scrape job name to be added in `otel_collector` sub-chart:
```yaml
job_name: "kepler"
```

---

## Node Resource Metrics
Keywords:
- node CPU usage
- node memory usage
- filesystem metrics
- network device metrics
- host-level resource metrics

Dependency to be added in the parent `observability_operator` chart:
```yaml
- name: prometheus-node-exporter
  version: 4.55.0
  repository: "https://prometheus-community.github.io/helm-charts"
```

Scrape job name to be added in `otel_collector` sub-chart:
```yaml
job_name: "node-exporter"
```

---

## Kubernetes Object Metrics
Keywords:
- pod status
- deployment status
- replica counts
- Kubernetes object state
- desired vs available replicas
- namespace-level Kubernetes metadata

Dependency to be added in the parent `observability_operator` chart:
```yaml
- name: kube-state-metrics
  version: 7.4.0
  repository: "https://prometheus-community.github.io/helm-charts"
```

Scrape job name to be added in `otel_collector` sub-chart:
```yaml
job_name: "kube-state-metrics"
```

---

## Container Resource Metrics
Keywords:
- container CPU usage
- container memory usage
- container filesystem usage
- pod-level resource usage
- container-level resource usage

No external helm dependency is required in the parent `observability_operator` chart.

Scrape job name to be added in `otel_collector` sub-chart:
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
- kubelet metrics
- pod lifecycle metrics
- volume metrics
- node runtime metrics

No external helm dependency is required in the parent `observability_operator` chart.

Scrape job name to be added in `otel_collector` sub-chart:
```yaml
job_name: "kubelet"
```

---

## Network Latency Metrics
Keywords:
- network latency
- inter-node latency
- network delay
- connectivity delay metrics

Dependency to be added in the `Chart.yaml` file of the parent `observability_operator` chart:
```yaml
- name: network-latency
  version: 0.1.0
  repository: "https://gitlab.com/api/v4/projects/44429468/packages/helm/stable"
```

Scrape job name to be added in `otel_collector` sub-chart:
```yaml
job_name: "network-latency"
```

---

## Logs
There are 2 types of logs.
## Application Logs
Application logs are emitted directly by the application using the OTLP protocol. Only the `otlp` receiver is needed to be enabled in the `otel_collector` sub-chart. No Fluent Bit. No tailing. No systemd. No containerd scraping.

## System Logs
System logs include:
- Kubernetes system component logs
- kubelet logs
- node logs
- cluster logs
- system logs
- containerd logs
- non-application logs
- journald lgos

Dependency to be added in the `Chart.yaml` file of the parent `observability_operator` chart:
```yaml
- name: fluent-bit
  version: 0.57.6
  repository: "https://fluent.github.io/helm-charts"
```

In the `values.yaml` file of the parent `observability_operator` chart, we must put some configuration for it, specifying inputs.

## Kubernetes Events Logs
When kubernetes events logs are requested, just the `k8s_events` receiver is needed to be added in the `otel_collector` sub-chart.

---

# Parent Chart Generation Rules
The parent chart `observability_operator` must always include:
```yaml
- name: otel-collector
  version: 0.1.0
  repository: "file://../otel_collector"
```

**Rules:**
- The parent chart must include only the absolutely needed dependencies. These dependencies are those required by the selected signals, based on user requests.
- Unnecessary dependencies must not be included.
- For each dependency name defined in the parent chart, we can override some of its values in the `values.yaml` file by using its name. For example, we can update the target for getting the `network-latency` chart dependency:
```yaml
network-latency:
  target_hosts:
    - cluster: example_target_cluster
      host_ip: ["10.0.0.1"]
```

---

# OpenTelemetry Collector Generation Rules
The agent must generate the `otel_collector` sub-chart dynamically.
The general idea is that we have **receivers**, **processors**, and **exporters**.

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

## required processors
The `batch` processor and the `resource` processor for specifying the cluster name are always needed. The configuration file should include:
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

## otlp exporter
The `otlp` exporter is needed, specifying the (ip, port) endpoint for sending the telemetry. The configuration file should include:
```yaml
exporters:
  otlp:
    endpoint: {{ .Values.otelCollector.exporters.otlp.host }}:{{ .Values.otelCollector.exporters.otlp.port }}
    tls:
      insecure: true
```

---

## otlp receiver
Include the `otlp` receiver only when:
- application traces are requested,
- application otlp metrics are requested,
- application otlp logs are requested.

The `otel_collector` sub-chart configuration file should include: 
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

## k8s_events receiver
Include the `k8s_events` receiver only when kubernetes cluster events as logs are requested. In this case, the `otel_collector` sub-chart configuration file should include:
```yaml
receivers:
  k8s_events:
    auth_type: serviceAccount
    namespaces: []
```

---

## prometheus receiver
Include the `prometheus` receiver only when Prometheus-compatible exporters are requested. These metrics are exported from kepler, kube-state, network-latency, kubelet, cadvisor. In this case, the `otel_collector` sub-chart configuration file should include:
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

For the case of `prometheus` receiver in `otel_collector` sub-chart configuration file, we should specify some scrape jobs.
The agent must use the following exact scrape-job templates. The agent must not invent alternative discovery rules unless the user explicitly changes service names or labels.

---

### kepler
When `kepler` is needed and is added as dependency in the `Chart.yaml` file of the  parent chart `observability_operator`, we need to specify this job:
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

In the `values.yaml` file of the parent chart `observability_operator`, we can override its name.

---

### node exporter
When `node-exporter` is needed and is added as dependency in the `Chart.yaml` file of the  parent chart `observability_operator`, we need to specify this job:
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

In the `values.yaml` file of the parent chart `observability_operator`, we can override its name.

---

### cAdvisor
When `cAdvisor` is needed, we need to specify this job:
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

### kubelet
When `kubelet` is needed, we need to specify this job:
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

### kube-state-metrics
When `kube-state-metrics` is needed and is added as dependency in the `Chart.yaml` file of the  parent chart `observability_operator`, we need to specify this job:
```yaml
- job_name: "kube-state-metrics"
  kubernetes_sd_configs:
    - role: "endpoints"
  relabel_configs:
    - source_labels: [__meta_kubernetes_service_name]
      action: keep
      regex: kube-state-metrics
```

In the `values.yaml` file of the parent chart `observability_operator`, we can override its name.

---

### network latency
When `network-latency` is needed and is added as dependency in the `Chart.yaml` file of the parent chart `observability_operator`, we need to specify this job:
```yaml
- job_name: "network-latency-agent"
  kubernetes_sd_configs:
    - role: "service"
  relabel_configs:
    - source_labels: [__meta_kubernetes_service_name]
      action: keep
      regex: network-latency-agent-service
```

In the `values.yaml` file of the parent chart `observability_operator`, we can override the target hosts by defining a cluster and its IPs.

---

# Pipeline Generation Rules
Generate only the **required pipelines**, using the **receivers**, **processors**, and **exporters** that were defined in the configuration file of `otel_collector` sub-chart.

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

then the `prometheus` receiver must exist.

If a pipeline references:

```yaml
otlp
```

then the `otlp` receiver must exist.

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
  - events
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

- only required receivers exist
- `prometheus` receiver exists only when scrape jobs exist
- each metrics dependency has a matching scrape job
- omitted dependencies must not have scrape jobs
- `otlp` exporter endpoint comes from user input
- cluster resource attribute exists through its `resource` processor

---

## Helm Validation

The generated chart must pass:

```bash
helm lint observability_operator_chart_<suffix>/observability_operator
```

and:

```bash
helm template observability_operator_chart_<suffix>/observability_operator
```

without errors.

---

# Reference Chart

The repository also includes a:

```text
reference-chart/
```

directory.

The reference chart is an example implementation only.

The agent must not blindly copy all dependencies or scrape jobs from the reference chart.

The agent must dynamically generate a minimal chart according to the requested signals.

The reference chart exists to:

- demonstrate Helm style,
- demonstrate templating conventions,
- demonstrate Collector configuration structure,
- demonstrate RBAC structure.

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
## reference-chart/observability_operator/values.yaml

```yaml
network-latency:
  target_hosts:
    - cluster: "localhost"
      host_ip: ["127.0.0.1"]
    - cluster: "custom_cluster"
      host_ip: ["192.168.1.100"]

prometheus-node-exporter:
  fullnameOverride: node-exporter

kube-state-metrics:
  fullnameOverride: kube-state-metrics

kepler:
  fullnameOverride: kepler

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
      # Pod logs
      # [INPUT]
          # Name              tail
          # Tag               kube.*
          # Path              /var/log/containers/*.log
          # multiline.parser  docker, cri
          # Mem_Buf_Limit     5MB
          # Skip_Long_Lines   On

      # k3s logs (includes kubelet, apiserver, scheduler, controller-manager)
      [INPUT]
          Name           tail
          Tag            k3s.*
          Path           /var/log/k3s.log

      # System logs (syslog)
      [INPUT]
          Name           tail
          Tag            syslog.*
          Path           /var/log/syslog

      # containerd logs from journald
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
          Host            otel-agent-service
          Port            4318
          Metrics_URI     /v1/metrics
          Logs_URI        /v1/logs
          Traces_URI      /v1/traces
          Log_response_payload False
          Tls             Off
          Logs_body_key   log
          Logs_body_key_attributes true
          Logs_attributes_metadata_key attributes
          Logs_resource_metadata_key resource
          Logs_instrumentation_scope_metadata_key scope

      [OUTPUT]
          Name            stdout
          Match           *
          Format          json_lines
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
    name: opentelemetry-collector-contrib
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
  - events
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
