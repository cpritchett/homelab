# Upstream Issue Draft: Komodo Swarm Stack Health Detection

**Repo:** [moghtech/komodo](https://github.com/moghtech/komodo)
**Status:** Draft (review before submitting)

---

## Title

Swarm stack health always shows Unhealthy — container name regex doesn't match Swarm naming convention

## Description

When using Komodo to manage Docker Swarm stacks (via the `swarm` resource), stack health is always reported as `Unhealthy` or `Down` even when all services are running correctly. This is because the container name matching regex assumes Docker Compose naming conventions, which differ from Docker Swarm's naming.

### Expected container names (Compose)

```
platform_monitoring-cadvisor-1
platform_monitoring-grafana-1
```

### Actual container names (Swarm)

```
platform_monitoring_cadvisor.1.mzjtscrtdqtpl9jq2qvsqotkd
platform_monitoring_grafana.1.umafms9y529p1p3mhxzu1ja4d
```

### Differences

| Aspect | Compose | Swarm |
|--------|---------|-------|
| Separator (stack/service) | `-` | `_` |
| Replica suffix | `-N` | `.slot.container_hash` |

### Root cause

In `bin/core/src/stack/services.rs`, service container names are constructed as:

```rust
container_name: format!("{project_name}-{service_name}")
```

In `bin/core/src/stack/mod.rs`, the matching regex is:

```rust
let regex = format!("^{container_name}-?[0-9]*$");
```

This regex matches `platform_monitoring-cadvisor-1` but not `platform_monitoring_cadvisor.1.abc123`.

In `bin/core/src/helpers/query.rs`, if no containers match any service, the state becomes `Down`. If some match but fewer than expected, it becomes `Unhealthy`.

### Impact

- All Swarm-deployed stacks show incorrect health status
- `ignore_services` config works correctly (services are filtered before matching) but the underlying match still fails for all remaining services
- Health alerts for Swarm stacks are unreliable

### Suggested fix

The regex could be extended to handle both naming conventions:

```rust
pub fn compose_container_match_regex(
  container_name: &str,
) -> anyhow::Result<Regex> {
  // Match both Compose naming (stack-service-N) and
  // Swarm naming (stack_service.slot.hash)
  let swarm_name = container_name.replace('-', "[_-]");
  let regex = format!("^{swarm_name}(-[0-9]*|\\.[0-9]+\\.[a-z0-9]+)?$");
  Regex::new(&regex).with_context(|| {
    format!("failed to construct valid regex from {regex}")
  })
}
```

Alternatively, for Swarm stacks specifically, health could be determined via `docker service ls` (which reports correct replica counts) rather than container name matching.

### Environment

- Komodo Core: `ghcr.io/moghtech/komodo-core:2-dev`
- Komodo Periphery: `ghcr.io/moghtech/komodo-periphery:2-dev`
- Docker Swarm mode with 5 nodes
- Stacks deployed via Komodo's Swarm resource type

### Related issues

- #464 (Unhealthy stack not being correctly reported)
- #939 (Unhealthy containers shown as running)
