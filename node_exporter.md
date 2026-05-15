# Node Exporter
Prometheus Node Exporter is the host metrics source for the Observability Operator.

It exposes hardware and OS-level metrics from Linux nodes in Prometheus format and is designed to run as a DaemonSet so that each cluster node can expose its own metrics.

The Observability Operator uses Node Exporter for low-level system metrics that are not available through the Kubernetes API.

## Metrics and Signals
Node Exporter exposes hundreds of system metrics, including:
- CPU metrics: usage, time, throttling
- Memory metrics: usage, cache, swap
- Disk metrics: I/O, space usage, reads/writes
- Network metrics: bytes transmitted/received, errors, dropped packets
- Filesystem metrics: inodes, free space
- Load and uptime metrics

Metrics are tagged with the Kubernetes node name when scraped through Kubernetes service discovery.

## Chart Contract
The parent Observability Operator chart should include Node Exporter as an external dependency.

Repository: https://prometheus-community.github.io/helm-charts

Pinned version: 4.55.0

Suggested chart name in the parent values: prometheus-node-exporter

## Natural Language Mapping
When the user asks for node-level or host-level metrics, the LLM should enable Node Exporter and configure the collector to scrape it.

Typical user intents:
- “collect CPU and memory metrics from nodes”
- “collect disk and network stats from the cluster nodes”
- “turn on host monitoring”

## Metrics Endpoint
Node Exporter serves metrics on `/metrics` over HTTP on port `9100`.

The collector should scrape that endpoint through the Prometheus receiver configuration.

## Permissions
The Observability Operator does not require special permissions to scrape Node Exporter.

Node Exporter itself does require node-level access, but that is handled by its chart automatically.

## Collector Dependency
The collector should include a scrape target for Node Exporter when the user requests node-level metrics.

Example config block in `otelCollector.receivers.prometheus`:
```yaml
node_exporter:
  service: prometheus-node-exporter
  port: 9100
  # namespace field not applicable; Node Exporter runs on all nodes
```

The LLM should keep the dependency boundary clear:
- Node Exporter chart owns deployment, service, and node access setup
- OTel Collector owns the scrape job that consumes the metrics
- parent chart owns dependency pinning and enablement flags

## RBAC Implications
Node Exporter itself requires DaemonSet permissions on nodes, handled by its own chart.
The collector does not need Kubernetes discovery RBAC to scrape Node Exporter if the service endpoint is known (e.g., `prometheus-node-exporter.default.svc.cluster.local:9100`).

**Important**: The parent chart does not control Node Exporter's RBAC. If you deploy the parent chart to a specific namespace, Node Exporter runs in that same namespace but may still have cluster-wide node access (determined by its own chart). If you want to restrict Node Exporter's node access, you must modify the values you pass to the Node Exporter dependency in the parent chart.

## RBAC Scope Values (LLM Reference)
When generating a parent chart with namespace-scoped requirements, check the prometheus-node-exporter Helm chart (https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus-node-exporter) for any RBAC-related values under `rbac.*` or `serviceAccount.*`.

Typical patterns to look for:
- `rbac.create`, `rbac.pspEnabled` (enable/disable RBAC creation)
- `serviceAccount.create`, `serviceAccount.name`, `serviceAccount.namespace` (ServiceAccount scope)
- Rarely: `rbac.scope` or similar (if the chart supports namespace-scoped Roles)

If the chart does not expose a namespace-scoped RBAC value, document this limitation in the parent chart's dependency values as an assumption.

## Troubleshooting
- Deployment Success
Verify that the node exporter DaemonSet, pods, and service objects exist in the cluster.

## Integration Check
Ensure that the OTel Collector scrape target points to the correct service and port for Node Exporter.