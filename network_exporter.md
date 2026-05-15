# Network Exporter
Network Exporter is a planned optional component for the Observability Operator, intended to provide network-level telemetry when that capability is explicitly chosen.

## Status
This component is not yet pinned to a repository or version in the current knowledge base.

The LLM should not generate a chart for this component until the user provides the desired repository, chart name, and version, or until this document is updated with those details.

## Intended Role
When defined, the component should be treated as a source of network metrics that the OTel Collector can scrape through a Prometheus-compatible endpoint.

## LLM Guidance
When a user asks for network telemetry:
- first decide whether the current knowledge base already contains a pinned network telemetry chart
- if not, ask for the repository and chart version or use another supported source the user already enabled
- keep the collector scrape configuration in the OTel Collector chart, not in the network component chart

## Documentation Contract
A future completed version of this file should answer:
- what network signals are exposed
- which workload or DaemonSet owns them
- what endpoint and port are used
- what repository and version are pinned
- what collector scrape flag enables the target
