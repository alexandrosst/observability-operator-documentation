# Observability Operator Chart Generation Guide
This document describes how an LLM agent should generate an `observability_operator_chart` based on a user's requested observability signals.

The generated Helm chart consists of:

1. A parent chart named `observability-operator`.
2. A local sub-chart named `otel-collector`.
3. Optional third-party dependency charts for telemetry exporters.

The agent must not include all exporters by default. Instead, it should select only the required Helm dependencies and configure the OpenTelemetry Collector only for the requested telemetry sources.

The parent chart is responsible for declaring dependencies.

The `otel-collector` chart is responsible for:
- receiving OTLP telemetry,
- scraping selected Prometheus-compatible exporters,
- enriching telemetry with cluster metadata,
- forwarding telemetry to a configured OTLP endpoint.

The generated chart should be minimal, meaning that unused exporters and unused Collector scrape jobs should not be included.