# Observability Chart Agent — Specification & Canonical Templates

This document is the **single source of truth** for the agent. It contains all generation rules, signal mappings, dependency versions, and canonical copy-paste templates. Read this file completely before generating any files.

---

## 1. Required Output Structure

```
observability_operator_chart_<clusterName>/
  observability_operator/
    Chart.yaml
    values.yaml
    templates/
      NOTES.txt              ← always required; helm lint --strict fails without it
  otel_collector/
    Chart.yaml
    values.yaml
    templates/
      otel-collector.yaml    ← ConfigMap + Deployment + Service
      permission.yaml        ← ServiceAccount + ClusterRole + ClusterRoleBinding
```

File path keys in chart_files must use this layout exactly, e.g.:
- `"observability_operator/Chart.yaml"`
- `"otel_collector/templates/otel-collector.yaml"`

This layout is required for the `file://../otel_collector` local dependency to resolve during validation.

---

## 2. User Input

**Required:**
- `clusterName` — name of the target cluster
- `otlpExportEndpoint.host` — hostname or IP of the OTLP export destination

**Optional (defaults):**
- `otlpExportEndpoint.port` → `4318`
- `scrapeInterval` → `5s`
- `evaluationInterval` → `5s`

**Signals** — all default to `false`; only set `true` when explicitly requested:

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

**Network latency targets** (required only when `networkLatency: true`):
```yaml
networkLatency:
  targets:
    - cluster: "<clusterName>"
      host_ip: ["<IP>"]
```

---

## 3. Signal → Component Mapping

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
| `systemLogs` | `fluent-bit` | — | — (Fluent Bit → HTTP) |
| `kubernetesEvents` | — | — | `k8s_events` |
| `traces` | — | — | `otlp` |

**RBAC:** add `nodes/proxy` to ClusterRole when `containerResources` or `kubelet` is requested.

---

## 4. Helm Dependency Versions

| Dependency | Version | Repository |
|---|---|---|
| `kepler` | `0.6.1` | `https://sustainable-computing-io.github.io/kepler-helm-chart` |
| `prometheus-node-exporter` | `4.55.0` | `https://prometheus-community.github.io/helm-charts` |
| `kube-state-metrics` | `7.4.0` | `https://prometheus-community.github.io/helm-charts` |
| `network-latency` | `0.1.0` | `https://gitlab.com/api/v4/projects/44429468/packages/helm/stable` |
| `fluent-bit` | `0.57.6` | `https://fluent.github.io/helm-charts` |

The local sub-chart is always included:
```yaml
- name: otel-collector
  version: 0.1.0
  repository: "file://../otel_collector"
```

---

## 5. Canonical File Templates

Copy these templates exactly. Substitute only the values indicated. Do not add, remove, or rename keys.

---

### `observability_operator/Chart.yaml`

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
  # Add only signal-required external dependencies below.
  # Use exact versions from the table in section 4.
```

---

### `observability_operator/values.yaml`

Include only keys for dependencies that are present in Chart.yaml.

```yaml
# Uncomment and fill in only the blocks for included dependencies.

# kepler:
#   fullnameOverride: kepler

# prometheus-node-exporter:
#   fullnameOverride: node-exporter

# kube-state-metrics:
#   fullnameOverride: kube-state-metrics

# network-latency:
#   name: network-latency-agent   # determines the Kubernetes Service name: <name>-service
#   target_hosts:
#     - cluster: "<clusterName>"
#       host_ip: ["<IP>"]
#   parameters:
#     interval: 5                 # scrape interval in seconds (integer, no 's' suffix)

# fluent-bit:
#   fullnameOverride: fluent-bit
#   <see Fluent Bit section below for full config>
```

---

### `observability_operator/templates/NOTES.txt`

```
Observability Operator deployed to cluster {{ .Values.otelCollector.clusterName }}.
```

---

### `otel_collector/Chart.yaml`

```yaml
apiVersion: v2
name: otel-collector
description: OpenTelemetry Collector sub-chart
type: application
version: 0.1.0
```

---

### `otel_collector/values.yaml`

**Copy this template exactly.** Fill in `clusterName`, `host`, `port`, `scrapeInterval`, `evaluationInterval` from user input. Do not omit any key — missing keys cause nil pointer errors in Helm templates.

```yaml
otelCollector:
  clusterName: "<clusterName>"
  scrapeInterval: 5s
  evaluationInterval: 5s
  deploymentName: otel-collector
  configMapName: otel-collector-config
  configChecksum: ""   # SHA-256 of the ConfigMap data block — computed and filled in by the agent at generation time
  serviceName: otel-collector
  replicas: 1
  image:
    registry: otel
    name: opentelemetry-collector-contrib
    tag: "0.98.0"
  exporters:
    otlp:
      host: "<host>"
      port: 4318
      tls:
        insecure: true
```

---

### `otel_collector/templates/otel-collector.yaml`

This file contains three Kubernetes manifests: ConfigMap, Deployment, Service.

**Critical rules:**
- The ConfigMap data key must be `otel-agent-config.yaml` — it must match the container arg `--config=/conf/otel-agent-config.yaml`.
- The pipeline section is static YAML — write it out explicitly, do not use `range` or any Helm loops.
- Include only receivers and pipelines for requested signals.
- Every receiver defined in `receivers:` must appear in exactly one pipeline. No unused receivers.
- A pipeline must not reference a receiver that is not defined.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Values.otelCollector.configMapName }}
data:
  otel-agent-config.yaml: |
    extensions:
      health_check:
        endpoint: 0.0.0.0:13133

    receivers:
      # prometheus: include if any scrape-based signal is requested
      # prometheus:
      #   config:
      #     global:
      #       scrape_interval: {{ .Values.otelCollector.scrapeInterval }}
      #       evaluation_interval: {{ .Values.otelCollector.evaluationInterval }}
      #     scrape_configs:
      #       <paste only the scrape jobs for requested signals — see section 6>

      # otlp: include if applicationMetrics, applicationLogs, or traces requested
      # otlp:
      #   protocols:
      #     grpc:
      #       endpoint: 0.0.0.0:4317
      #     http:
      #       endpoint: 0.0.0.0:4318

      # k8s_events: include only if kubernetesEvents requested
      # k8s_events:
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
        # metrics: include when any metrics signal is requested
        # metrics:
        #   receivers: [prometheus]   # add otlp here too if applicationMetrics requested
        #   processors: [resource, batch]
        #   exporters: [otlp]

        # logs: include when applicationLogs, systemLogs, or kubernetesEvents requested
        # logs:
        #   receivers: [otlp]         # add k8s_events here if kubernetesEvents requested
        #   processors: [resource, batch]
        #   exporters: [otlp]

        # traces: include only when traces requested
        # traces:
        #   receivers: [otlp]
        #   processors: [resource, batch]
        #   exporters: [otlp]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.otelCollector.deploymentName | default "otel-collector" }}
spec:
  replicas: {{ .Values.otelCollector.replicas }}
  selector:
    matchLabels:
      app: {{ .Values.otelCollector.deploymentName | default "otel-collector" }}
  template:
    metadata:
      labels:
        app: {{ .Values.otelCollector.deploymentName | default "otel-collector" }}
      annotations:
        checksum/config: {{ .Values.otelCollector.configChecksum }}
    spec:
      serviceAccountName: {{ .Values.otelCollector.deploymentName | default "otel-collector" }}
      containers:
        - name: {{ .Values.otelCollector.deploymentName | default "otel-collector" }}
          image: "{{ .Values.otelCollector.image.registry }}/{{ .Values.otelCollector.image.name }}:{{ .Values.otelCollector.image.tag }}"
          imagePullPolicy: Always
          args: ["--config=/conf/otel-agent-config.yaml"]
          volumeMounts:
            - name: config-volume
              mountPath: /conf
          readinessProbe:
            httpGet:
              path: /
              port: 13133
              scheme: HTTP
            initialDelaySeconds: 1
            periodSeconds: 3
            successThreshold: 1
            failureThreshold: 3
            timeoutSeconds: 2
      volumes:
        - name: config-volume
          configMap:
            name: {{ .Values.otelCollector.configMapName }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.otelCollector.serviceName }}
spec:
  selector:
    app: {{ .Values.otelCollector.deploymentName | default "otel-collector" }}
  ports:
    # Include otlp-grpc and otlp-http only when the otlp receiver is defined.
    # Omit entirely if no otlp receiver.
    # - name: otlp-grpc
    #   protocol: TCP
    #   port: 4317
    #   targetPort: 4317
    # - name: otlp-http
    #   protocol: TCP
    #   port: 4318
    #   targetPort: 4318
```

---

### `otel_collector/templates/permission.yaml`

Copy exactly. Use `| default "otel-collector"` on every name reference. Add `nodes/proxy` when `containerResources` or `kubelet` is requested.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .Values.otelCollector.deploymentName | default "otel-collector" }}
  namespace: {{ .Release.Namespace }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: {{ .Values.otelCollector.deploymentName | default "otel-collector" }}
rules:
  - apiGroups: [""]
    resources: [pods, nodes, services, endpoints, events]
    verbs: [get, list, watch]
  # Uncomment when containerResources or kubelet is requested:
  # - apiGroups: [""]
  #   resources: [nodes/proxy]
  #   verbs: [get, list, watch]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: {{ .Values.otelCollector.deploymentName | default "otel-collector" }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: {{ .Values.otelCollector.deploymentName | default "otel-collector" }}
subjects:
  - kind: ServiceAccount
    name: {{ .Values.otelCollector.deploymentName | default "otel-collector" }}
    namespace: {{ .Release.Namespace }}
```

---

## 6. Scrape Job Templates

Include only the jobs for requested signals. Paste them verbatim under `scrape_configs:`.

### `kepler` — signal: `energy`
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

### `node-exporter` — signal: `nodeResources`
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

### `cadvisor` — signal: `containerResources`
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

### `kube-state-metrics` — signal: `kubernetesState`
```yaml
- job_name: "kube-state-metrics"
  kubernetes_sd_configs:
    - role: "endpoints"
  relabel_configs:
    - source_labels: [__meta_kubernetes_service_name]
      action: keep
      regex: kube-state-metrics
```

### `kubelet` — signal: `kubelet`
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

### `network-latency-agent` — signal: `networkLatency`
The service name is `<network-latency.name>-service`. The scrape job regex must
match it exactly — use the same `name` value set in the parent `values.yaml`.
```yaml
- job_name: "network-latency-agent"
  kubernetes_sd_configs:
    - role: "service"
  relabel_configs:
    - source_labels: [__meta_kubernetes_service_name]
      action: keep
      regex: <network-latency.name>-service   # e.g. network-latency-agent-service
```

---

## 7. Fluent Bit Configuration — signal: `systemLogs`

Add this block in `observability_operator/values.yaml` when `systemLogs` is requested.

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

## 8. Helm Templating Rules

- Use `$${1}` not `${1}` in Prometheus relabel `replacement` values.
- Use `{{ .Release.Namespace }}` in ClusterRoleBinding subjects.
- Use `| default "otel-collector"` on every `deploymentName` reference.
- The ConfigMap data key must be `otel-agent-config.yaml`.
- Container args must be `["--config=/conf/otel-agent-config.yaml"]`.
- Do not use `tpl`, `include`, `range`, or any helper functions — write all YAML statically.
- Do not rely on `| default` for `tls.insecure` — define it explicitly in values.yaml.
