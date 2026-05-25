# Validation Checklist
After generating the chart, the agent must verify the following.

## Parent chart
- `observability_operator/Chart.yaml` exists.
- The chart name is `observability-operator`.
- The `otel-collector` dependency is always included.
- Only requested exporter dependencies are included.
- No unused dependency chart is included.

## Collector chart
- `otel_collector/Chart.yaml` exists.
- `otel_collector/values.yaml` exists.
- `otel_collector/templates/otel-collector.yaml` exists.
- `otel_collector/templates/permission.yaml` exists.

## Collector configuration
- The Collector includes only required receivers.
- The Prometheus receiver is present only if Prometheus scrape jobs exist.
- Each selected exporter has a matching scrape job.
- No scrape job exists for an omitted dependency.
- The metrics pipeline includes `prometheus` only when Prometheus scraping is enabled.
- The OTLP exporter endpoint is configured from user input.
- The `cluster` resource attribute is configured from user input.

## RBAC

RBAC must include:

```yaml
resources:
  - pods
  - nodes
  - nodes/proxy
  - services
  - endpoints
```