# Required File Structure
The agent must generate the following chart structure:

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

The parent chart is `observability_operator`. 
The local Collector sub-chart is `otel_collector`.

The parent chart must declare otel-collector as a local dependency using:

```yaml
repository: "file://../otel_collector"
```

The agent must not place Collector Kubernetes manifests directly inside the parent chart. Collector manifests belong inside:

```text
otel_collector/templates/
```

The parent chart must contain dependency declarations only. Component-specific Kubernetes manifests should come from either:
- external dependency charts, or
- the local otel_collector chart.

