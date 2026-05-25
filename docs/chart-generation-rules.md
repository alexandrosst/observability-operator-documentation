# Chart Generation Rules

The agent must generate the parent `Chart.yaml` based only on requested telemetry sources.
The parent chart must always include the local `otel-collector` dependency.

```yaml
- name: otel-collector
  version: 0.1.0
  repository: "file://../otel_collector"
```

The agent must add third-party dependencies only when required.

## Example: energy only
If the user requests only energy metrics, include:

```yaml
dependencies:
  - name: kepler
    version: 0.6.1
    repository: "https://sustainable-computing-io.github.io/kepler-helm-chart"
  - name: otel-collector
    version: 0.1.0
    repository: "file://../otel_collector"
```

The Collector should include only the Kepler scrape job.

## Example: resource usage only
If the user requests node and container resource usage, include:

```yaml
dependencies:
  - name: prometheus-node-exporter
    version: 4.55.0
    repository: "https://prometheus-community.github.io/helm-charts"
  - name: otel-collector
    version: 0.1.0
    repository: "file://../otel_collector"
```

The Collector should include:

```yaml
job_name: "node-exporter"
job_name: "cadvisor"
```

cAdvisor does not require a Helm dependency because it is scraped through the Kubernetes API server.

## Example: full metrics stack
If the user requests energy, node resources, container resources, Kubernetes object state, kubelet metrics, and network latency, include:

```yaml
dependencies:
  - name: kube-state-metrics
    version: 7.3.0
    repository: "https://prometheus-community.github.io/helm-charts"
  - name: prometheus-node-exporter
    version: 4.55.0
    repository: "https://prometheus-community.github.io/helm-charts"
  - name: kepler
    version: 0.6.1
    repository: "https://sustainable-computing-io.github.io/kepler-helm-chart"
  - name: network-latency-agent
    version: 0.1.0
    repository: "https://gitlab.com/api/v4/projects/44429468/packages/helm/stable"
  - name: otel-collector
    version: 0.1.0
    repository: "file://../otel_collector"
```