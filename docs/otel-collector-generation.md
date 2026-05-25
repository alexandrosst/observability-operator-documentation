# OpenTelemetry Collector Generation Rules
The agent must generate the Collector configuration according to the requested telemetry sources.

## Always include
The Collector configuration must always include:

```yaml
extensions:
  health_check:
    endpoint: 0.0.0.0:13133
```

The Collector should always include the OTLP exporter:

```yaml
exporters:
  otlp:
    endpoint: <host>:<port>
    tls:
      insecure: <true|false>
```

The Collector should always include these processors:

```yaml
processors:
  batch:
  resource:
    attributes:
      - key: cluster
        value: <clusterName>
        action: insert
```

## Receivers
The `otlp` receiver should be included when the user needs application traces, metrics, or logs through OTLP.

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
```

The `prometheus` receiver should be included when at least one Prometheus-compatible exporter is used.

```yaml
receivers:
  prometheus:
    config:
      global:
        scrape_interval: <scrapeInterval>
        evaluation_interval: <evaluationInterval>
      scrape_configs:
        ...
```

## Scrape job selection
The agent must include only the scrape jobs required by the selected telemetry sources. Do not include unused scrape jobs.

When Prometheus scraping is used, the agent must copy scrape jobs from `scrape-job-templates.md` and must not invent new discovery rules unless the user explicitly changes service names or labels.

## Pipelines
The metrics pipeline should include prometheus only when Prometheus scraping is configured.

Example:

```yaml
service:
  extensions:
    - health_check
  pipelines:
    metrics:
      receivers:
        - prometheus
      processors:
        - resource
        - batch
      exporters:
        - otlp
```

If OTLP metrics are also needed:

```yaml
receivers:
  - otlp
  - prometheus
```

The traces pipeline should be included only if traces are requested.

The logs pipeline should be included only if logs are requested.