# Helm Templating Conventions
The agent must follow these Helm templating rules when generating the chart.

## General rules
Do not hardcode user-provided deployment values directly in templates.

Use `.Values` references for configurable parameters such as:

```yaml
clusterName
deploymentName
replicas
configMapName
serviceName
image registry
image name
image tag
OTLP exporter host
OTLP exporter port
TLS mode
Collector ports
scrape interval
evaluation interval
```

## Collector values namespace
All Collector-specific values must be placed under: `otelCollector:`.

Example:
```yaml
otelCollector:
  clusterName: my-cluster
  deploymentName: otel-agent
  replicas: 1
  configMapName: otel-agent-config-map
  serviceName: otel-agent-service
```

## Dependency and scrape-job consistency
Every selected Helm dependency must have a matching Collector scrape job when the dependency exposes Prometheus metrics.

```text
Kepler dependency -> kepler scrape job
prometheus-node-exporter dependency -> node-exporter scrape job
kube-state-metrics dependency -> kube-state-metrics scrape job
network-latency-agent dependency -> network-latency-agent scrape job
```

cAdvisor and kubelet do not require Helm dependencies, but they do require Collector scrape jobs.

## Prometheus relabel escaping
When Prometheus relabeling needs ${1}, escape it as $${1} inside Helm templates.

Correct:
```yaml
replacement: "/api/v1/nodes/$${1}/proxy/metrics/cadvisor"
```

Incorrect: 
```yaml
replacement: "/api/v1/nodes/${1}/proxy/metrics/cadvisor"
```

## Namespace references
Use the release namespace for ServiceAccount references in ClusterRoleBinding:
```yaml
namespace: {{ .Release.Namespace }}
```

## Resource attribute
The Collector must insert the cluster name as a resource attribute:
```yaml
processors:
  resource:
    attributes:
      - key: cluster
        value: {{ .Values.otelCollector.clusterName }}
        action: insert
```

## OTLP exporter endpoint
The OTLP exporter endpoint must be assembled from values:
```yaml
endpoint: {{ .Values.otelCollector.exporters.otlp.host }}:{{ .Values.otelCollector.exporters.otlp.port }}
```

## Collector ports
Expose only the ports required by the selected receivers.
For OTLP HTTP:
```yaml
port: 4318
targetPort: 4318
```

For OTLP gRPC:
```yaml
port: 4317
targetPort: 4317
```

## Pipeline generation
Generate only the required pipelines.
If only metrics are requested, generate only:
```yaml
service:
  pipelines:
    metrics:
```

If traces are requested, add:
```yaml
traces:
```

If logs are requested, add:
```yaml
logs:
```

## Receiver consistency
If the metrics pipeline uses `prometheus`, the Prometheus receiver must exist.

If the traces, metrics, or logs pipeline uses `otlp`, the OTLP receiver must exist.

Do not reference receivers that are not defined.

## Processor consistency
If a pipeline references resource or batch, these processors must be defined.

## Exporter consistency
If a pipeline references `otlp`, the OTLP exporter must be defined.