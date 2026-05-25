# Required User Inputs
Before generating the chart, the agent should identify the following user inputs.

## Required inputs
```yaml
clusterName: ""
otlpExportEndpoint:
  host: ""
  port: 4318
  protocol: http
tls:
  insecure: true
```

## Requested telemetry sources
The user should specify one or more of:

```yaml
signals:
  energy: true
  nodeResources: true
  containerResources: true
  kubernetesState: true
  kubelet: true
  networkLatency: true
  logs: true
```

## Optional inputs
```yaml
collector:
  image:
    registry: otel
    name: opentelemetry-collector
    tag: latest
  replicas: 1
  scrapeInterval: 5s
  evaluationInterval: 5s
  deploymentName: otel-agent
  serviceName: otel-agent-service
  configMapName: otel-agent-config-map
```

If optional inputs are not provided, the agent should use the defaults above.

