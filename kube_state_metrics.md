# Kube State Metrics
kube-state-metrics is the cluster state source for the Observability Operator.

It listens to the Kubernetes API and generates Prometheus-formatted metrics about the state of Kubernetes objects. It does not measure resource usage; it reports object state.

The Observability Operator uses kube-state-metrics to enrich telemetry with cluster-level metadata and workload health information.

## Metrics and Signals
kube-state-metrics produces state-based metrics for Kubernetes objects, including:
- Pod state: phase, ready status, restart count, resource requests/limits
- Deployment state: replicas desired, updated, available, ready
- DaemonSet, StatefulSet, Job state: similar status and count metrics
- Node state: ready status, memory/disk pressure
- PVC state: volume used/available
- Service and Endpoint state: counts and status
- Resource quota usage and limits

These metrics are purely descriptive (not resource usage) and allow correlation between workload lifecycle and performance changes.

## Chart Contract
The parent Observability Operator chart should include kube-state-metrics as an external dependency.

Repository: https://prometheus-community.github.io/helm-charts

Pinned version: 7.3.0

Suggested chart name in the parent values: kube-state-metrics

## Natural Language Mapping
When the user asks for cluster-state visibility, the LLM should enable kube-state-metrics and configure the collector to scrape it.

Typical user intents:
- “collect workload state metrics”
- “show pod and deployment status metrics”
- “track Kubernetes object state in the dashboard”

## Kubernetes Objects Covered
KSM exposes metrics for the following object types:
- Pods
- Deployments
- ReplicaSets
- DaemonSets
- StatefulSets
- Jobs / CronJobs
- Nodes
- Namespaces
- Services
- PersistentVolumes / PersistentVolumeClaims
- ResourceQuotas
- HorizontalPodAutoscalers

This allows the suite to correlate system metrics with Kubernetes object state.

## Metrics Endpoint
KSM serves metrics on `/metrics` over HTTP on port `8080`.

The collector should scrape that endpoint through the Prometheus receiver configuration.

## Permissions
The Observability Operator does not require special permissions to scrape kube-state-metrics.

kube-state-metrics itself does require Kubernetes API access, but that is handled by its own chart automatically.

## Collector Dependency
The collector should include a scrape target for kube-state-metrics when the user requests cluster state visibility.

Example config block in `otelCollector.receivers.prometheus`:
```yaml
kube_state_metrics:
  namespace: ""  # empty = all namespaces; set to a specific namespace if desired
  service: kube-state-metrics
  port: 8080
```

The LLM should keep the dependency boundary clear:
- kube-state-metrics chart owns the workload that reads cluster state
- OTel Collector owns the scrape job that consumes the metrics
- parent chart owns dependency pinning and enablement flags

## Namespace Filtering
If the user asks to observe "only the production namespace", set `namespace: production` in the scrape config.
If they ask for "all namespaces", leave `namespace: ""` or omit it.

## RBAC Implications
If you use Kubernetes service discovery with namespace filtering, the collector needs a Role scoped to that namespace.
If you hardcode the service endpoint (`kube-state-metrics.kube-system.svc.cluster.local:8080`), no discovery RBAC is needed.

**Important**: The parent chart does not control kube-state-metrics' RBAC. kube-state-metrics' own chart creates its ServiceAccount and Role/ClusterRole. If you want to restrict what namespaces kube-state-metrics can read from, you must pass values to the kube-state-metrics dependency in the parent chart to narrow its RBAC scope. This is not automatic and requires the KSM chart to support namespace-scoped RBAC values.

## RBAC Scope Values (LLM Reference)
When generating a parent chart with namespace-scoped requirements, check the kube-state-metrics Helm chart (https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-state-metrics) for RBAC-related values under `rbac.*` or `kubeStateMetrics.replicas.*`.

Typical patterns to look for:
- `rbac.create`, `rbac.clustered` (controls whether RBAC is cluster-wide or not)
- `serviceAccount.create`, `serviceAccount.name`, `serviceAccount.namespace`
- `kubeStateMetrics.namespaces` (if supported, restricts which namespaces KSM queries)
- `kubeStateMetrics.namespaceRegex` (if supported, allows regex-based namespace filtering)

If the chart does not expose a way to restrict RBAC or query scope to specific namespaces, document this limitation in the parent chart's dependency values as an assumption.


## Troubleshooting
- Deployment Success
Verify that the kube-state-metrics deployment, pods, and service objects exist in the cluster.

## Integration Check
Ensure that the OTel Collector scrape target points to the correct service and port for kube-state-metrics.