# Supported Observability Signals
The agent should map user requests to observability components.

## Energy metrics
Use Kepler when the user requests:
- energy metrics
- power consumption
- node energy
- pod energy
- container energy
- sustainability metrics

Required dependency:
```yaml
- name: kepler
  version: 0.6.1
  repository: "https://sustainable-computing-io.github.io/kepler-helm-chart"
```

Required Collector scrape job:
```yaml
job_name: "kepler"
```

## Node resource metrics
Use Prometheus Node Exporter when the user requests:
- node CPU usage
- node memory usage
- filesystem metrics
- network device metrics
- host-level resource metrics

Required dependency:
```yaml
- name: prometheus-node-exporter
  version: 4.55.0
  repository: "https://prometheus-community.github.io/helm-charts"
```

Required Collector scrape job:
```yaml
job_name: "node-exporter"
```

## Kubernetes object metrics
Use kube-state-metrics when the user requests:
- pod status
- deployment status
- replica counts
- Kubernetes object state
- desired vs available replicas
- namespace-level Kubernetes metadata

Required dependency:
```yaml
- name: kube-state-metrics
  version: 7.3.0
  repository: "https://prometheus-community.github.io/helm-charts"
```

Required Collector scrape job:
```yaml
job_name: "kube-state-metrics"
```

## Container resource metrics
Use kubelet/cAdvisor scraping when the user requests:
- container CPU usage
- container memory usage
- container filesystem usage
- pod-level resource usage
- container-level resource usage

No external Helm dependency is required.

Required Collector scrape job:
```yaml
job_name: "cadvisor"
```

The Collector service account must have access to:
```yaml
resources:
  - nodes
  - nodes/proxy
```

## Kubelet metrics
Use kubelet scraping when the user requests:
- kubelet metrics
- pod lifecycle metrics
- volume metrics
- node runtime metrics exposed by kubelet

No external Helm dependency is required.

Required Collector scrape job:
```yaml
job_name: "kubelet"
```

## Network latency metrics
Use the network latency agent when the user requests:
- network latency
- inter-node latency
- network delay
- connectivity delay metrics

Required dependency:
```yaml
- name: network-latency-agent
  version: 0.1.0
  repository: "https://gitlab.com/api/v4/projects/44429468/packages/helm/stable"
```

Required Collector scrape job:
```yaml
job_name: "network-latency-agent"
```

## Logs
Use Fluent Bit when the user requests:
- container logs
- pod logs
- Kubernetes logs
- node logs

Required dependency:
```yaml
- name: fluent-bit
  version: 0.57.6
  repository: "https://fluent.github.io/helm-charts"
```

The Collector logs pipeline should be included only if logs are sent to the Collector through OTLP or another configured receiver.