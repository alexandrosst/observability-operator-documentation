# cAdvisor (Built-in)

cAdvisor runs inside the kubelet process and exposes container-level metrics such as container CPU, memory, filesystem, and network usage.

- Not an installable Helm chart; part of kubelet on each node.
- Metrics: container_cpu_usage_seconds_total, container_memory_usage_bytes, container_fs_usage_bytes, container_network_receive_bytes_total, etc.
- Discovery: scraped via node discovery or via node-exporter endpoints if aggregated.

RBAC and scraping:
- The collector needs node discovery permissions if relying on Kubernetes service discovery.
- No separate RBAC or ServiceAccount exists for cAdvisor itself.

Collector scrape config example (prometheus receiver):

receivers:
  prometheus:
    configs:
      - job_name: 'cadvisor'
        kubernetes_sd_configs:
          - role: node
        metrics_path: /metrics/cadvisor

Notes for the LLM:
- Do not invent a cAdvisor Helm chart. Instead, generate appropriate collector scrape targets and ensure discovery RBAC is present when needed.
