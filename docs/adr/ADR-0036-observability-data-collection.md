# ADR-0036: Observability Data Collection

**Status:** Accepted
**Date:** 2026-02-11
**Authors:** Platform Engineering
**Supersedes:** None
**Relates to:** ADR-0034 (Label-Driven Infrastructure), ADR-0033 (TrueNAS Swarm Migration)

## Context

The monitoring stack (Prometheus, Loki, Grafana) was deployed in the Swarm migration (ADR-0033) but remained operationally hollow:

- Prometheus scraped only itself, Grafana, and Loki (3 targets)
- Loki had zero log streams (no shipper sending logs)
- No host-level metrics (CPU, RAM, disk, network)
- No container-level metrics (per-container CPU, memory, network)
- No Grafana dashboards provisioned from code
- No retention policy configured on Loki

Without data collectors, the monitoring stack provided no operational visibility and could not fulfill its intended role as the observability layer.

## Decision

Add three standard Prometheus ecosystem collectors to the monitoring stack, configure log retention, and provision Grafana dashboards from version-controlled JSON files.

### Collectors

| Service | Image | Purpose | Deploy Mode |
|---------|-------|---------|-------------|
| node-exporter | `prom/node-exporter:v1.8.2` | Host metrics (CPU, memory, disk, network, filesystem) | `global` |
| cAdvisor | `gcr.io/cadvisor/cadvisor:v0.51.0` | Per-container metrics (CPU, memory, network, I/O) | `global` |
| Promtail | `grafana/promtail:2.9.8` | Ship Docker container logs to Loki | `global` |

All three deploy in `global` mode (one instance per Swarm node) and join only the internal `monitoring` overlay network. None are exposed through Caddy ingress.

### Log Retention

Loki retention set to 14 days (336h) with compactor enabled. This aligns with the existing Prometheus TSDB retention of 15 days.

### Dashboards

Four community dashboards provisioned from JSON files:

| Dashboard | Grafana.com ID | Purpose |
|-----------|---------------|---------|
| Node Exporter Full | 1860 | Host CPU, memory, disk, network |
| Docker Container Monitoring | 14282 | Per-container metrics from cAdvisor |
| Loki & Promtail Quick Search | 13186 | Log search and exploration |
| Prometheus Stats | 3662 | Prometheus self-monitoring |

Datasource references hardcoded to provisioned UIDs (`prometheus`, `loki`).

## Rationale

### Why These Collectors

- **node-exporter**: The de facto standard for Linux host metrics in the Prometheus ecosystem. Lightweight, well-maintained, and has extensive community dashboard support.
- **cAdvisor**: Native container metrics exporter from Google. Provides per-container CPU, memory, and I/O without requiring application instrumentation.
- **Promtail**: Chosen over Grafana Alloy and the Docker logging driver for several reasons:
  - Alloy is newer and has less Swarm-specific documentation
  - Docker logging driver requires daemon-level configuration changes and restarts
  - Promtail's `docker_sd_configs` provides automatic container discovery with rich label extraction (container name, Swarm service, stack namespace)

### Why Global Mode

All collectors need to run on every node to capture host and container data. Swarm `mode: global` ensures automatic scheduling on current and future nodes.

### Why Internal-Only

These services expose raw metrics and logs. They do not need external access and are consumed only by Prometheus and Loki within the `monitoring` overlay network.

### Why Provisioned Dashboards

Version-controlling dashboard JSON ensures dashboards survive Grafana data loss and can be reviewed in pull requests. The `updateIntervalSeconds: 60` setting allows Grafana to pick up file changes without restart.

## Consequences

### Positive

- All Swarm services automatically emit metrics and logs without per-service configuration
- Host-level visibility (CPU, memory, disk, network) available immediately
- Container-level visibility (per-container resource usage) available immediately
- Log search available through Grafana with stack/service/container labels
- 14-day retention prevents unbounded disk growth
- Dashboards are version-controlled and reproducible
- AutoKuma labels on all three collectors provide automatic uptime monitoring

### Negative

- Docker socket mounted read-only into cAdvisor and Promtail (required for container discovery)
- cAdvisor adds ~512MB memory overhead per node
- Promtail positions file requires persistent storage (`/mnt/apps01/appdata/monitoring/promtail-positions`)

### Prometheus Scrape Targets (After)

| Job | Target | Metrics |
|-----|--------|---------|
| prometheus | `prometheus:9090` | Self-monitoring |
| grafana | `grafana:3000` | Grafana internals |
| loki | `loki:3100` | Loki internals |
| node-exporter | `node-exporter:9100` | Host metrics |
| cadvisor | `cadvisor:8080` | Container metrics |
| promtail | `promtail:9080` | Promtail internals |
