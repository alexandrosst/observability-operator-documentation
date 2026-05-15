# Kepler
Kepler is the energy telemetry source for the Observability Operator.

Kepler (Kubernetes Efficient Power Level Exporter) estimates and exposes energy consumption metrics for Kubernetes nodes, pods, and containers.
It uses hardware counters, eBPF, and model-based estimation to provide fine-grained energy telemetry metrics.

The Observability Operator uses Kepler to enrich system and workload metrics with energy usage data.

## Metrics and Signals
Kepler exposes energy and power metrics:
- Node-level energy consumption (Joules, power in Watts)
- Pod-level power attribution
- Container-level energy usage
- Hardware counter-based estimation for CPU, DRAM, network, disk power
- Model-based estimates for workloads that cannot directly measure power

Kepler metrics allow you to understand energy efficiency, optimize workload placement, and track sustainability goals.

## Chart Contract
The parent Observability Operator chart should include Kepler as an external dependency.

Repository: https://sustainable-computing-io.github.io/kepler-helm-chart

Pinned version: 0.6.1

Suggested chart name in the parent values: kepler

## Natural Language Mapping
When the user asks for energy telemetry or power-related observability, the LLM should enable Kepler and configure the collector to scrape it.

Typical user intents:
- “collect power consumption metrics”
- “measure energy usage for nodes and workloads”
- “show energy efficiency metrics in observability”

## Observability Operator Integration
Kepler should be integrated in the parent chart as a dependency.

Kepler exposes its metrics on `/metrics` over HTTP on port `9102`.

The collector should scrape that endpoint through the Prometheus receiver configuration.

## Permissions
The Observability Operator does not require special permissions to scrape Kepler.

Kepler itself may require privileged host access depending on the deployment mode, but that is handled by its own chart automatically.

## Collector Dependency
The collector should include a scrape target for Kepler when the user requests energy telemetry.

Example config block in `otelCollector.receivers.prometheus`:
```yaml
kepler:
  service: kepler
  port: 9102
  # namespace field not typically needed; Kepler is usually cluster-wide
```

The LLM should keep the dependency boundary clear:
- Kepler chart owns the energy exporter deployment and its host-level access setup
- OTel Collector owns the scrape job that consumes the metrics
- parent chart owns dependency pinning and enablement flags

## RBAC Implications
Kepler runs cluster-wide and exposes node-level energy metrics.
The collector does not need Kubernetes discovery RBAC if the service endpoint is known (e.g., `kepler.default.svc.cluster.local:9102`).
If the collector uses Kubernetes service discovery, it needs cluster-wide permissions to discover Kepler endpoints.

**Important**: The parent chart does not control Kepler's RBAC. Kepler's own chart determines its permissions and deployment scope. If you want to restrict Kepler's access, you must modify the values you pass to the Kepler dependency in the parent chart.

## RBAC Scope Values (LLM Reference)
When generating a parent chart with namespace-scoped requirements, check the Kepler Helm chart (https://github.com/sustainable-computing-io/kepler-helm-chart) for any RBAC-related values under `rbac.*` or `serviceAccount.*`.

Typical patterns to look for:
- `rbac.create`, `rbac.pspEnabled` (enable/disable RBAC creation)
- `serviceAccount.create`, `serviceAccount.name`, `serviceAccount.namespace`
- Rarely: namespace or scope restriction values (Kepler is typically cluster-wide)

If the Kepler chart does not support namespace-scoped RBAC, document this in the parent chart's dependency values. Note: Kepler is primarily a cluster-level energy monitoring tool, so namespace-scoped access may not be meaningful.

## Troubleshooting
- Deployment Success
Verify that the Kepler deployment, pods, and service objects exist in the cluster.

## Integration Check
Ensure that the OTel Collector scrape target points to the correct service and port for Kepler.