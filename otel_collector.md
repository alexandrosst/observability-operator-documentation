# OTel Collector
The OTel Collector is the custom Helm subchart that provides the shared telemetry pipeline for the Observability Operator.

It is responsible for receiving, processing, and exporting telemetry collected from the enabled components in the parent chart.

This file should be treated as the implementation contract for an LLM that needs to generate the collector chart from a descriptive request.

## Role In The Parent Chart
The parent chart should declare the collector as a local dependency and the collector chart should own all collector-specific manifests.

That means the parent chart may pass collector values, but it should not render collector scrape ConfigMaps, Deployments, Services, or pipeline documents itself.

The collector chart should not be treated as a generic upstream chart copy. It is the place for the operator-specific scrape config, pipeline wiring, RBAC, and deployment settings.

## Helm Structure Skeleton
Use this as the syntax reference for the local collector chart:

```text
otel-collector/
  Chart.yaml
  values.yaml
  templates/
    _helpers.tpl
    configmap.yaml
    deployment.yaml
    service.yaml
    permission.yaml
```

Keep the canonical collector settings under `otelCollector.*` in the collector chart values. The parent chart should forward those values into the dependency, but the collector chart remains the source of truth for its own templates and resource names.

Minimal collector-chart shape:

```yaml
# Chart.yaml
apiVersion: v2
name: otel-collector
type: application
version: 0.1.0
appVersion: dev
```

```yaml
# values.yaml
otelCollector:
  clusterName: ""
  deploymentName: otel-collector
  replicas: 1
  configMapName: otel-collector-config-map
  serviceName: otel-collector-service
```

## What The LLM Should Infer From User Requests
The collector chart is usually the place where natural-language observability requests become actual configuration.

Examples:
- “collect node metrics” should enable the node exporter scrape target and the related Prometheus receiver job
- “collect cluster state” should enable kube-state-metrics scraping
- “collect energy metrics” should enable Kepler scraping
- “include kubelet and cadvisor metrics” should enable the node-level Kubernetes scrape jobs
- “scrape every 15 seconds” should update the collector scrape interval, not the application charts unless they also expose scrape intervals
- “send everything to my backend” should update the OTLP exporter host, port, and TLS settings

## Inputs
The chart should be driven by values instead of hardcoded names.

Important inputs include:
- cluster name
- replica count
- scrape interval and evaluation interval
- collector image, registry, tag, and pull policy
- internal service and ConfigMap names
- OTLP listen endpoint
- OTLP export endpoint and TLS mode
- enabled Prometheus scrape targets
- pipeline definitions
- optional debug exporter toggle
- service account and RBAC names if they are not derived from helpers

## Canonical Values
Use one canonical values path per setting.

- `otelCollector.scrapeInterval`: default scrape interval for the collector-generated Prometheus jobs
- `otelCollector.evaluationInterval`: evaluation interval when the collector renders Prometheus-style scrape config
- `otelCollector.scrapeTimeout`: timeout used for scrape jobs
- `otelCollector.receivers.otlp`: OTLP listen endpoint
- `otelCollector.receivers.prometheus.*`: scrape target blocks (only include targets that are needed)
- `otelCollector.exporters.otlp.host` and `otelCollector.exporters.otlp.port`: backend export destination
- `otelCollector.exporters.tls.*`: backend TLS behavior
- `otelCollector.features.debugExporter`: local debug output toggle

If a setting appears in both a top-level field and a nested field, the top-level field is the authoritative user-facing default and the nested field should only be used by the rendered config, not as a second source of truth.

## Outputs
The collector chart should create the following Kubernetes resources:
- a ConfigMap with the generated collector configuration
- a Deployment for the collector runtime
- a Service for exposing collector ports if needed
- a ServiceAccount for the collector pod
- RBAC objects when the collector needs cluster reads for Prometheus discovery

## Template Responsibilities
The collector template set should be split by concern:
- `templates/configmap.yaml` or equivalent: render the OpenTelemetry config file.
- `templates/deployment.yaml`: run the collector with the mounted config.
- `templates/service.yaml`: expose collector endpoints.
- `templates/rbac.yaml`: define service account, cluster role, and binding if scrape discovery requires it.

The generated config should be built from values and should enable or disable scrape jobs with conditionals, not through duplicated collector charts.

The template set should also preserve the same names used by the parent chart values so the LLM does not invent parallel naming schemes.

## Pipeline Contract
The collector should be configured as the aggregation point for:
- traces through OTLP
- metrics through OTLP and Prometheus scrape jobs
- logs only if the parent chart later adds a logs pipeline

The default collector config should include:
- `health_check` extension
- `batch` processor
- `resource` processor that adds cluster metadata
- `otlp` exporter to the destination configured by values
- `debug` exporter only if you explicitly want local debugging output

The pipeline configuration should be values-driven so that the LLM can generate new pipelines without rewriting chart logic.

## Prometheus Scrape Targets
The chart should define scrape targets for endpoints that are explicitly included in the user request or the parent chart configuration.

Use a **presence-based** configuration model: only include a scrape target in the collector config if the user actually wants it. Do not use boolean flags like `enabled: true/false`. Instead, if the target is needed, add its config block to values; if not, omit it entirely.

Recommended targets (include only those requested):
- `kepler`: energy consumption metrics from the Kepler exporter
- `node_exporter`: host-level metrics from Prometheus Node Exporter
- `kube_state_metrics`: Kubernetes object state from kube-state-metrics
- `cadvisor`: container resource metrics from Kubernetes node agents
- `kubelet`: node and pod metrics from the Kubernetes kubelet
- optional custom services such as network telemetry agents

The documentation should be explicit that the collector discovers those endpoints, while the component charts themselves still come from separate dependencies.

Recommended collector scrape settings:
- scrape interval should default to a safe short interval such as 5s or 15s, but remain configurable
- evaluation interval should match scrape interval unless the user requests a different behavior
- scrape timeout should stay lower than the scrape interval
- TLS verification settings should be configurable for the OTLP backend and for Kubernetes APIs when required

## Default Behavior
If the user does not specify a value:
- use a short but safe scrape interval such as 5s or 15s
- keep the evaluation interval equal to the scrape interval
- keep the scrape timeout lower than the scrape interval
- disable the debug exporter by default
- keep `health_check` enabled unless the user explicitly turns it off
- keep scrape flags off only for data sources the user did not request, unless the chart is meant to ship with opinionated defaults

## Values Contract
A good `values.yaml` shape for the collector looks like this:

```yaml
otelCollector:
  clusterName: ""
  deploymentName: otel-collector
  replicas: 1
  scrapeInterval: 5s
  evaluationInterval: 5s
  scrapeTimeout: 3s
  configMapName: otel-collector-config-map
  serviceName: otel-collector-service
  image:
    registry: otel
    name: opentelemetry-collector
    tag: latest
    pullPolicy: IfNotPresent
  receivers:
    otlp: 0.0.0.0:4318
    prometheus:
      # Only include scrape targets that are actually needed.
      # Omit a block entirely if the source is not requested.
      # Example: if the user asks for node metrics, include node_exporter below.
      # If they do not, remove this block entirely.
      node_exporter:
        namespace: ""  # empty string = all namespaces
        service: prometheus-node-exporter
        port: 9100
      # cadvisor block example (only if kubelet metrics are needed):
      # cadvisor:
      #   kubernetes_sd: true
      # kube_state_metrics block example (only if cluster state is needed):
      # kube_state_metrics:
      #   namespace: ""
      #   service: kube-state-metrics
      #   port: 8080
  exporters:
    otlp:
      host: ""
      port: 4318
    tls:
      insecure: true
      caFile: ""
  pipelines:
    traces:
      receivers: [otlp]
      exporters: [otlp]
      processors: [resource, batch]
    metrics:
      receivers: [otlp, prometheus]
      exporters: [otlp]
      processors: [resource, batch]
    logs:
      receivers: [otlp]
      exporters: [otlp]
      processors: [resource, batch]
  ports:
    otlp-grpc:
      port: 4318
      targetPort: 4318
  features:
    debugExporter: false
    healthCheck: true
```

The generated chart should preserve this nesting pattern:
- parent chart dependency values: `otel-collector.otelCollector.*`
- collector chart canonical values: `otelCollector.*`
- resource names derived from helpers rather than hardcoded strings wherever possible

## Values Resolution Rules
When generating values from user intent:
- include only the scrape target blocks that the user actually requested; omit unused targets entirely
- do not add a source unless the user asked for it or it is explicitly required by the requested pipeline
- prefer top-level timing defaults over repeating timing values inside scrape target blocks
- keep backend export settings separate from scrape settings
- if the user asks for "everything", include all relevant targets but with explicit values for each
- if the user specifies a namespace filter, set that namespace in the scrape target block; if they want all namespaces, use an empty string or omit the field

Use snake_case for nested feature flags and keep the parent chart responsible for the final dependency names and versions.

## Chart Generation Rules
When generating the collector chart, the LLM should follow these rules:
- prefer values and helpers over hardcoded literals
- keep scrape jobs in a single generated OpenTelemetry config document
- use the same feature flag names in the docs and the chart values
- keep the deployment, service, config map, and RBAC separated by template file or clear template block
- do not add application-specific telemetry logic unless it was requested by the user
- include only the scrape targets that are actually enabled in values

## Chart Guidance For The LLM
When generating the collector chart, the LLM should prefer these rules:
- keep the chart minimal and values-driven
- use named helpers for labels and fullname if the repo already uses them
- keep scrape config in one generated collector config file
- keep RBAC separate from the collector config
- avoid hardcoding release names, namespaces, or hostnames unless they are intentionally fixed
- pin the parent dependency version in the root chart and keep the collector as a local path dependency

## What The Parent Chart Should Delegate
The parent chart should delegate the following to this subchart:
- collector deployment and service
- generated OpenTelemetry config
- cluster-aware RBAC for Prometheus discovery
- feature flags for which telemetry sources are active

This keeps the root chart focused on dependency wiring and leaves the collector chart responsible for the telemetry control plane.

## RBAC Scope
The collector requires different permissions depending on how it discovers and scrapes targets:
- **Cluster-wide scraping**: if the collector uses Kubernetes service discovery to find targets across all namespaces, it needs a ClusterRole with `get`, `list`, `watch` on `nodes`, `endpoints`, `pods`, and `services`.
- **Namespace-scoped scraping**: if the collector only scrapes targets in specific namespaces, it can use a namespaced Role instead of ClusterRole, and the binding is a RoleBinding instead of ClusterRoleBinding.
- **No discovery needed**: if scrape targets are hard-coded as `<service>.<namespace>.svc.cluster.local` endpoints, no Kubernetes discovery RBAC is needed.

The collector's RBAC is **independent** from the RBAC of the component charts. The parent chart controls the collector's RBAC; each external component chart (Node Exporter, KSM, Kepler) controls its own RBAC.

Decide the collector's RBAC scope based on the user's request:
- If they ask to observe \"everything\" or the \"whole cluster\", generate a ClusterRole for the collector.
- If they ask to observe \"a specific namespace\" or \"these namespaces\", generate a namespaced Role scoped to those namespaces.
- Always prefer the minimum required scope.

## Namespace Filtering
When a scrape target supports namespace filtering, add a `namespace` field to the scrape block:
```
prometheus:
  kube_state_metrics:
    namespace: "production"  # only scrape this namespace
```

If `namespace` is empty or omitted, the collector defaults to scraping all namespaces (which may require cluster-wide RBAC).

Namespace filtering is useful when:
- the user asks to observe only certain environments (e.g., "just the production namespace")
- the cluster has multi-tenant isolation and each tenant should see only their own metrics
- the user wants to reduce cardinality by excluding development or test namespaces

## Validation Checklist
Before considering the collector spec complete, verify that:
- every included scrape target has a clear source and endpoint
- the OTLP backend fields are present if export is required
- scrape intervals and scrape timeout are coherent
- the RBAC scope matches the discovery scope (cluster-wide role for cluster discovery, namespaced role for namespace discovery)
- if namespace filtering is used, the RBAC is also correctly scoped
- the config map, deployment, service, and RBAC responsibilities are not duplicated in the parent chart
- the values structure can be derived from user intent without guessing field names