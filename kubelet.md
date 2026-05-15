# Kubelet (Built-in)

Kubelet is a built-in Kubernetes node agent that exposes kubelet and cAdvisor metrics on each node.

- Not an installable Helm chart; runs on every Kubernetes node.
- Metrics: kubelet and node-level metrics (node_cpu_seconds_total, node_memory_MemAvailable_bytes, pod/cgroup metrics), summaries and runtime stats.
- Discovery: collectors discover kubelet endpoints via Kubernetes node discovery (endpoints like `<node-ip>:10250` or via `kubelet` service DNS when available).

RBAC and scraping:
- The OTel Collector needs permissions to discover nodes and endpoints if using Kubernetes service discovery (`get`, `list`, `watch` on `nodes`, `endpoints`).
- If you hardcode kubelet/cAdvisor endpoints by DNS, no Kubernetes discovery RBAC is required.

Collector scrape config example (prometheus receiver):

receivers:
  prometheus:
    configs:
      - job_name: 'kubelet'
        kubernetes_sd_configs:
          - role: node
        relabel_configs:
          - source_labels: [__meta_kubernetes_node_name]
            target_label: node

Notes for the LLM:
- Do not attempt to generate a Helm chart for kubelet or cAdvisor—they are cluster components.
- When a user asks to "collect kubelet metrics", generate collector scrape config and ensure collector RBAC covers node discovery.
