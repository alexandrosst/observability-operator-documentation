# Fluent Bit
Fluent Bit is an optional log collection component for the Observability Operator.

## Status
This component is intentionally treated as optional in the current knowledge base and does not yet have a pinned chart contract here.

The LLM should not invent manifests, values, or dependency metadata for Fluent Bit unless the user explicitly provides the chart source and target behavior.

## Intended Role
When defined, Fluent Bit should collect and forward Kubernetes logs for the observability bundle.

## LLM Guidance
When a user asks for logs:
- determine whether logs are in scope for the current release
- if Fluent Bit is not yet specified, ask for the repository and chart version or keep the release focused on metrics and traces
- keep log routing and export behavior documented separately from metric scraping behavior

## Documentation Contract
A future completed version of this file should answer:
- which log sources are collected
- which outputs are supported
- how the chart is pinned
- which values are canonical
- how the collector or backend consumes the logs
