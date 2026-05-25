# Observability Operator
The Observability Operator is a modular observability bundle for Kubernetes. Its goal is to provide a single installation path for the collection components that gather node, cluster, energy, and telemetry signals.

This repository is organized as a knowledge base for an LLM that will later generate or modify Helm charts from descriptive user requests.

## Chart Model
The top-level Helm chart is the entrypoint. It should install the platform-wide components and wire them together through subchart dependencies and shared values.

The parent chart must stay at the dependency and values layer:
- it declares external dependencies in `Chart.yaml`
- it passes values into child charts
- it does not render collector ConfigMaps, Deployments, Services, or scrape jobs directly
- it does not duplicate any manifest that belongs to a child chart

The OTel Collector implementation belongs in the local `otel-collector` subchart. If a request changes collector behavior, that change should appear as collector values or collector templates, not as duplicated parent-chart templates.

The dependency model should be explicit:
- External charts are consumed from published repositories and pinned to exact versions.
- Local charts are used only for components that need custom behavior, such as the OTel Collector.
- The parent chart should not duplicate child manifests when a child chart already owns them.

## Helm Structure Skeleton
Use this file layout as the syntax reference for generated charts:

```text
observability-operator/
	Chart.yaml
	values.yaml
	templates/
		_helpers.tpl
	charts/
		otel-collector/
```

If the parent chart declares a dependency named `otel-collector`, install-time overrides must use that exact dependency name as the values prefix. The collector subchart should keep its own canonical values under `otelCollector.*`, while the parent chart is responsible for passing those values down through the dependency boundary.

Use aliases only when the generated chart deliberately needs a different install-time name from the chart name, and keep the alias consistent in `Chart.yaml` and in the values path used by `helm install --set`.

Minimal parent-chart shape:

```yaml
# Chart.yaml
apiVersion: v2
name: observability-operator
type: application
version: 0.1.0
dependencies:
	- name: kepler
		version: 0.6.1
		repository: https://sustainable-computing-io.github.io/kepler-helm-chart
	- name: otel-collector
		version: 0.1.0
		repository: file://../otel-collector
```

```yaml
# values.yaml
otel-collector:
	otelCollector:
		clusterName: ""
		deploymentName: otel-collector
```

## Dependency Matrix
Use this mapping as the canonical relationship between user intent, parent-chart enablement, and collector scrape targets.

| User intent | Parent chart dependency | Collector scrape block | Notes |
| --- | --- | --- | --- |
| Node metrics | `prometheus-node-exporter` | `receivers.prometheus.node_exporter` | Host CPU, memory, disk, network; include block if requested |
| Cluster state | `kube-state-metrics` | `receivers.prometheus.kube_state_metrics` | Kubernetes object state; include block if requested |
| Energy metrics | `kepler` | `receivers.prometheus.kepler` | Node and workload energy telemetry; include block if requested |
| Kubelet metrics | none | `receivers.prometheus.kubelet` | Uses Kubernetes node discovery; include block if requested |
| cAdvisor metrics | none | `receivers.prometheus.cadvisor` | Uses Kubernetes node discovery; include block if requested |
| Backend export | none | `exporters.otlp.host`, `exporters.otlp.port`, `exporters.tls.*` | External telemetry backend; always required |

**Key principle**: Use presence-based configuration. If a user asks for a metric source, add its scrape block to the collector values and, when applicable, add the matching dependency entry in `Chart.yaml`. If they don't ask for it, omit the block entirely. Do not use enabled flags like `kepler.enabled`.

## LLM Decision Flow
When a user describes a desired observability setup in natural language, the LLM should:
1. Identify which components are required.
2. Decide whether each component is an external dependency or a custom local chart.
3. Determine the scope of observability: cluster-wide, namespace-scoped, or multi-namespace?
4. For each component requested, check its Helm chart documentation to see if it supports namespace-scoped RBAC values. Ask the user if scope is unclear.
5. Translate the request into values, not direct manifest edits, whenever the behavior is configurable.
6. Keep the parent chart focused on dependency wiring and global defaults.
7. Keep component-specific logic in the matching child chart documentation.
8. Prefer one canonical value path for each setting.
9. If a component doesn't support namespace-scoped RBAC, document this limitation as an assumption in the generated values.yaml.
10. If a request is ambiguous, choose the safest default and document the assumption in generated output.

Examples of user intent that should map to values:
- “Collect node metrics” should enable the node exporter dependency and the collector scrape target for it.
- “Collect Kubernetes object state” should enable kube-state-metrics and the corresponding collector scrape target.
- “Collect energy metrics” should add the Kepler dependency and the corresponding collector scrape target, with the scrape configuration owned by the collector subchart.
- “Scrape every 10 seconds” should become the collector scrape interval and any compatible component scrape intervals.
- “Send metrics to my backend” should configure the collector OTLP exporter host, port, and TLS mode.

## Collection Components
The operator can include the following components:
- `otel-collector`: custom local chart that defines the shared ingestion, processing, and export pipeline.
- `kepler`: external chart for energy telemetry from nodes and workloads.
- `prometheus-node-exporter`: external chart for host and node-level metrics.
- `kube-state-metrics`: external chart for Kubernetes object-state metrics.
- `fluent-bit`: optional log collection component if logs are part of the release.
 - `kubelet` / `cAdvisor`: built-in Kubernetes components (see `kubelet.md` and `cadvisor.md`). These are not separate Helm charts.

## Optional Components Status
The following components are part of the broader observability story, but they should only be generated as charts when their repository, version, and desired behavior are explicitly defined:
- `network-exporter`: network telemetry source, currently not pinned in this knowledge base.
- `fluent-bit`: log collection source, currently treated as optional and not fully specified for chart generation.

The LLM should not invent versions, repositories, or manifests for these components unless the user adds those details or this knowledge base is extended.

## Recommended File Roles
- `overview.md`: architecture, naming, dependency boundaries, and LLM decision flow.
- `otel_collector.md`: full collector chart contract and value schema.
- `kepler.md`: component summary and chart pinning for Kepler.
- `node_exporter.md`: component summary and chart pinning for Node Exporter.
- `kube_state_metrics.md`: component summary and chart pinning for kube-state-metrics.
- `network_exporter.md`: optional network telemetry component contract when added.
- `fluent_bit.md`: optional log collection component contract when added.

## Namespace Scoping
The operator supports three independent layers of namespace control. Understand the difference:

### Layer 1: Deployment Namespace
This is where the charts are physically installed. Use `helm install --namespace <namespace>` or values to specify it.
- **Default**: all charts deploy to the `default` namespace unless you specify otherwise.
- **Behavior**: the parent chart and all subcharts deploy to the same namespace.
- **Control**: this is standard Helm behavior and does not require any special chart logic.

Example:
```bash
helm install collection-agent ./collection-agent-chart --namespace observability
```

### Layer 2: Component RBAC Scope
This controls what **each component chart** can access in the cluster. Each external component (Node Exporter, KSM, Kepler) has its own RBAC defined by its chart.
- **Node Exporter**: runs as a DaemonSet and does not need Kubernetes API access. It only reads the node filesystem.
- **kube-state-metrics**: needs Kubernetes API access. Its chart creates a ServiceAccount with a Role/ClusterRole. If you want KSM to only see certain namespaces, you must pass values to the KSM chart to scope its RBAC. This is **not** handled by the parent chart.
- **Kepler**: similar to Node Exporter; runs as a Deployment and may not need API access depending on its mode.

**Important**: The parent chart does not modify or restrict the RBAC of its subcharts. If a dependency's chart creates cluster-wide RBAC by default, you either:
- Accept cluster-wide visibility for that component, or
- Override the component's values to use narrower RBAC (if the component chart supports it), or
- Manually patch the component's RBAC after installation.

**For the LLM**: If the user asks for namespace-scoped permissions for a tool:
1. **Check the component's chart documentation** (node-exporter, kube-state-metrics, kepler Helm repos) to see if it supports namespace-scoped RBAC values.
2. **If it does**: generate the parent chart's dependency values block with the appropriate RBAC scope (e.g., `namespace: production` or `rbac.scope: namespace`). Document these values clearly.
3. **If it doesn't**: document in the generated values.yaml as an **assumption** that the user may need to manually patch the component's Role/RoleBinding after installation. Provide an example patch command or YAML snippet.
4. **Example assumption comment**: `# TODO: The kube-state-metrics chart (v7.3.0) does not support namespace-scoped RBAC via values. To restrict KSM to the 'production' namespace, manually patch the Role/RoleBinding after installation, or upgrade the KSM chart if a newer version supports namespace scoping.`

### Layer 3: Collector Scraping Scope
This controls what **the OTel Collector** actually observes and is independent of Layers 1 and 2.
- **Collector deployment namespace**: the OTel Collector pod runs in the same namespace as the parent chart (Layer 1).
- **Collector RBAC**: determines which targets the collector's ServiceAccount can discover. Can be cluster-wide or namespace-scoped.
- **Collector scrape config**: determines which targets the collector actually scrapes. You can filter by namespace or hardcode service DNS names.

Collector scrape configuration belongs to the OTel Collector subchart. The parent chart may surface the values that feed it, but it should not render the collector scrape config itself.

Example: even if the collector has cluster-wide RBAC, you can choose to scrape only the `production` namespace by setting `namespace: "production"` in the scrape target values.

### Practical Examples

**Scenario 1: Observe everything cluster-wide**
- Layer 1: Deploy to `monitoring` namespace.
- Layer 2: All components use their default RBAC (usually cluster-wide).
- Layer 3: Collector has ClusterRole RBAC and scrapes all targets with `namespace: ""` (all namespaces).

**Scenario 2: Observe only the production namespace**
- Layer 1: Deploy to `monitoring` namespace.
- Layer 2: Pass values to each component to restrict their RBAC to the `production` namespace (requires component chart support).
- Layer 3: Collector has a namespaced Role scoped to `production` and scrapes with `namespace: "production"`.

**Scenario 3: Observe multiple tenants independently**
- Layer 1: Deploy separate parent charts to each tenant's namespace (e.g., `observability-tenant-a`).
- Layer 2: Each parent chart's dependencies are scoped to their own namespace.
- Layer 3: Each collector scrapes only its own namespace.

## Naming Convention
Use the same terms across the parent chart, child docs, and generated values.

- Parent chart: `collection-agent` or another top-level bundle name chosen by the user.
- Collector chart: `otel-collector` as the local subchart name.
- Feature flags: snake_case under `receivers.prometheus.*`.
- Export settings: structured under `exporters.otlp.*` and `exporters.tls.*`.
- Resource names: derive from helpers unless the user requests explicit names.

Do not invent parallel names for the same concept. If the docs say `node_exporter`, the generated values should not also use `nodeExporter` for the same flag.

## Generation Rules
The LLM should prefer these rules across the repository:
- keep names consistent between parent values and child values
- pin chart versions in the parent dependency list
- use local subcharts only when the chart needs custom templates or config generation
- keep all configurable scrape targets behind explicit configuration (not hidden in defaults)
- default to safe values that can be overridden by the user request
- avoid hardcoding release names, namespaces, or backend endpoints unless the user asks for fixed values
- document every non-obvious default so the generated chart is explainable to a reviewer
- keep one value source of truth for scrape timing, backend export, and feature enablement
- the parent chart controls **only** dependency wiring, top-level values, and the collector's RBAC; component RBAC must be controlled by passing values to each component's dependency, not by the parent chart
- if a user asks for namespace-scoped observability and a component does not support namespace-scoped RBAC values, **document this as an assumption** so the user knows they may need manual configuration

## Prompting Guidance for LLM-User Interaction
When a user's intent is unclear about scope, the LLM should ask these clarifying questions:

- **On namespace scope**: "Do you want the collector to observe the entire cluster, or just specific namespaces like `production`?"
- **On component scope**: "Should each monitoring tool (Node Exporter, kube-state-metrics, Kepler) have cluster-wide access, or access to only specific namespaces?"
- **On component RBAC limitation**: If a component chart doesn't support namespace-scoped RBAC values, inform the user: "The [component] Helm chart (version X.Y.Z) deploys with cluster-wide RBAC by default. I can generate the parent chart, but you may need to manually restrict its Role/RoleBinding after installation if you want it narrower. Should I proceed with cluster-wide, or do you have a custom values override?"

## Documentation Rules For The LLM
When generating or updating the charts, the LLM should treat these docs as the source of truth for:
- chart boundaries and ownership
- dependency sources and version pinning
- required values and defaults
- which templates belong to the parent chart versus the OTel Collector subchart
- scrape targets that the collector must enable or disable
- how to map descriptive user intent into chart values and enabled dependencies

## Desired Output
The generated Helm structure should follow this pattern:
- `Chart.yaml` at the top level for the observability bundle.
- a local `otel-collector` subchart for the custom collector behavior.
- a clear `values.yaml` contract that toggles integrations instead of hardcoding them.
- reusable labels, service accounts, RBAC, and config maps where needed.

## Validation Checklist
The LLM should validate the generated chart mentally and, if possible, mechanically against this checklist:
- the top-level chart has pinned dependency versions
- every enabled dependency has a corresponding collector scrape target or a documented reason not to scrape it
- the collector config renders with no duplicated pipelines or unsupported values
- scrape intervals and timeouts are internally consistent
- RBAC exists only where the collector or a dependency actually needs it
- the chart name, service names, and labels are consistent across templates and values

## Prompting Guidance
When the user gives only descriptive goals, the LLM should respond by first deciding what to enable, then by generating values, and only then by writing or updating templates. If the user request leaves a gap, the LLM should choose a sensible default and note the assumption rather than stalling.

## Quality Bar
The documentation should be detailed enough that another LLM can generate the chart with minimal guessing. Each component file should answer:
- what the component does
- why the operator needs it
- how to enable or disable it
- what Helm repository and version to use
- what collector settings it requires

The entire doc set should also answer:
- which values are canonical
- which settings are shared across the parent and child charts
- which choices are optional versus required
- how to validate that the generated chart matches the requested observability scope

The collector documentation should be the detailed implementation guide. The overview should remain a compact architecture map.