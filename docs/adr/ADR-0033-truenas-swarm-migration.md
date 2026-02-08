# ADR-0033: TrueNAS Scale Migration with Hybrid Kubernetes/Docker Swarm Architecture

**Status:** Accepted
**Date:** 2025-02-07
**Authors:** System Architect
**Supersedes:** None
**Relates to:** ADR-0032 (1Password Secrets Management)

## Context

The homelab currently runs on a Talos Linux Kubernetes cluster with 46 HelmReleases across 12 namespaces. While Kubernetes provides excellent orchestration capabilities, it introduces significant complexity for:

1. **Stateless workloads** that don't require Kubernetes-specific features
2. **Media stack applications** with simple dependencies that are over-engineered in k8s
3. **Infrastructure maintenance** requiring expertise in Flux, Helm, Kustomize, and k8s internals
4. **Resource utilization** where k8s overhead is disproportionate to workload needs

Simultaneously, TrueNAS Scale has emerged as a robust platform that:
- Runs Docker Swarm natively
- Provides ZFS-backed storage with excellent snapshot/replication features
- Offers a stable base OS with long-term support
- Includes built-in monitoring and management tools

The decision point is: **Should we migrate from pure Kubernetes to a hybrid architecture using TrueNAS Scale with Docker Swarm?**

## Decision

We will migrate to a **hybrid architecture** with:

1. **TrueNAS Scale** as the primary infrastructure platform running Docker Swarm
2. **Kubernetes cluster** maintained for k8s-native applications that benefit from k8s features
3. **Three-tier stack organization** on Docker Swarm (infrastructure/platform/application)
4. **Unified monitoring** across both orchestrators via federated Prometheus and centralized Loki
5. **Wazuh SIEM** deployment for security monitoring across all platforms

### Migration Scope

**Migrate to Docker Swarm:**
- Infrastructure tier: 1Password Connect, Komodo, Caddy
- Platform tier: Authentik, Forgejo, Woodpecker, Grafana, Loki, Wazuh, Restic
- Application tier: Media stack (12 apps), home automation (Mosquitto, Zigbee2MQTT, Home Assistant)

**Remain in Kubernetes:**
- GitOps: Flux
- Policy enforcement: Kyverno
- Certificate management: cert-manager
- Secret injection: External Secrets Operator
- CNI: Cilium
- Storage: Longhorn, VolSync
- K8s-specific apps: Backstage, Actions Runner Controller

### Bootstrap Strategy

Infrastructure tier will be bootstrapped via systemd service on TrueNAS boot:
1. Initialize Docker Swarm
2. Create overlay networks
3. Create Swarm secrets from files
4. Deploy op-connect → komodo → caddy in sequence
5. All subsequent deployments via Komodo UI

## Rationale

### Benefits of Hybrid Approach

1. **Simplicity for stateless workloads:**
   - Media stack apps (Sonarr, Radarr, etc.) are straightforward in Docker Compose
   - No need for HelmReleases, Kustomizations, or CRDs for simple services
   - Direct docker-compose.yaml files are easier to understand and maintain

2. **Preserve k8s strengths:**
   - GitOps via Flux remains intact for k8s workloads
   - Policy enforcement via Kyverno continues to protect k8s cluster
   - External Secrets Operator integration with 1Password (ADR-0032) preserved

3. **TrueNAS advantages:**
   - ZFS snapshots for instant backups of application data
   - Native Docker support eliminates virtualization layer
   - Excellent storage management and replication
   - Built-in monitoring via Grafana integration

4. **Operational improvements:**
   - Bootstrap script ensures infrastructure survives reboots
   - Komodo UI provides visual stack management
   - Caddy handles TLS automatically with DNS challenges
   - Reduced dependency on external control plane (Flux)

5. **Resource efficiency:**
   - Docker Swarm has lower overhead than k8s for simple workloads
   - TrueNAS can run on single-node initially, scale to cluster later
   - Media stack doesn't need k8s scheduling complexity

### Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **1Password Connect failure breaks all stacks** | CRITICAL | Keep k8s External Secrets as backup; comprehensive bootstrap testing; monitoring alerts |
| **Komodo unavailable blocks deployments** | HIGH | Document manual `docker stack deploy` process; keep compose files in Git |
| **Data loss during migration** | CRITICAL | Backup all k8s PVCs before migration; test restores; staged rollout with 2-week rollback window |
| **Complexity of managing two orchestrators** | MEDIUM | Unified monitoring via Grafana; centralized logging via Loki; single 1Password vault for secrets |
| **Knowledge gap - Docker Swarm** | LOW | Extensive documentation; simpler than k8s; team training via migration process |
| **TrueNAS Scale update breaking Docker** | MEDIUM | Pin TrueNAS release channel; test updates in staging; maintain k8s cluster as fallback |

## Alternatives Considered

### Alternative 1: Stay Pure Kubernetes

**Rejected because:**
- Over-engineered for stateless media stack apps
- Operational complexity disproportionate to benefits
- Requires ongoing Flux/Helm/Kustomize expertise
- Higher resource overhead for simple workloads

**Would choose if:**
- Team size grew to 5+ engineers
- Workloads required auto-scaling, multi-region HA
- Compliance required k8s-specific audit trails

### Alternative 2: Pure Docker Swarm (Abandon k8s)

**Rejected because:**
- Loses valuable k8s ecosystem tools (Flux, Kyverno, cert-manager)
- GitOps workflow is excellent for version-controlled infrastructure
- External Secrets Operator integration with 1Password is mature
- Backstage developer portal requires k8s

**Would choose if:**
- Workloads were entirely stateless microservices
- Team had zero k8s experience
- Budget constraints prevented maintaining k8s cluster

### Alternative 3: Docker Compose on VMs (No Orchestration)

**Rejected because:**
- No service orchestration or health management
- Manual failover and updates
- No automatic TLS certificate management
- Loses benefits of Swarm overlay networking

**Would choose if:**
- Single-node deployment with no HA requirements
- Applications didn't need ingress/TLS automation
- Team strongly preferred manual control

### Alternative 4: Nomad Orchestration

**Rejected because:**
- Additional tooling to learn (Consul, Vault)
- Smaller ecosystem than k8s or Docker Swarm
- Less mature integration with TrueNAS
- No compelling advantage over Swarm for this use case

**Would choose if:**
- Multi-cloud deployment required
- Needed batch/scheduled job orchestration
- Team already invested in HashiCorp stack

## Implementation Plan

### Phase 1: Infrastructure Foundation (Week 1) ✓

**Status:** IN PROGRESS

- [x] Fix 1Password Connect configuration inconsistencies
- [x] Fix Komodo template path references
- [x] Create TrueNAS bootstrap script
- [x] Create systemd service documentation
- [ ] Deploy and validate infrastructure tier on TrueNAS

**Success Criteria:**
- Bootstrap script runs idempotently
- op-connect, komodo, caddy stacks healthy
- Komodo UI accessible with TLS
- 1Password secret injection working

### Phase 2: Platform Services (Week 2)

- [ ] Deploy monitoring stack (Grafana, Loki, Prometheus)
- [ ] Configure Prometheus federation (k8s ← Swarm)
- [ ] Deploy Wazuh SIEM and agents
- [ ] Create Grafana dashboards for hybrid architecture
- [ ] Validate unified monitoring

**Success Criteria:**
- Grafana shows metrics from both k8s and Swarm
- Loki aggregates logs from both platforms
- Wazuh agents reporting from TrueNAS and k8s nodes
- Alerting works across both orchestrators

### Phase 3: Application Migration - Media Stack (Week 3-4)

- [ ] Create Docker Compose files for 12 media apps
- [ ] Create 1Password items and templates
- [ ] Deploy in staging (test environment)
- [ ] Migrate data from k8s PVCs to TrueNAS datasets
- [ ] Cutover DNS to Swarm services
- [ ] Validate media workflows (Prowlarr → Sonarr → Plex)

**Success Criteria:**
- All media apps accessible and functional
- Downloads completing successfully
- Plex transcoding working (QuickSync)
- Data persisted to ZFS datasets

### Phase 4: Application Migration - Home Automation (Week 5)

- [ ] Deploy Mosquitto MQTT broker
- [ ] Deploy Zigbee2MQTT with USB passthrough
- [ ] Migrate Home Assistant to Docker Swarm
- [ ] Test MQTT integrations

**Success Criteria:**
- Zigbee devices communicating
- Home automation workflows functional
- MQTT message flow validated

### Phase 5: Cleanup (Week 6+)

- [ ] Remove migrated apps from k8s cluster
- [ ] Delete unused k8s PVCs
- [ ] Archive k8s manifests
- [ ] Update documentation
- [ ] Create runbooks for operations

**Success Criteria:**
- k8s cluster reduced to core services only
- Documentation reflects hybrid architecture
- Team trained on new deployment workflows

## Consequences

### Positive

1. **Simpler operations** for media stack and stateless apps
2. **Better resource utilization** - right-sized orchestration for workload complexity
3. **Faster deployments** - docker-compose.yaml is easier to iterate on than Helm charts
4. **TrueNAS integration** - native storage management and snapshots
5. **Knowledge diversity** - team gains Docker Swarm expertise alongside k8s
6. **Flexibility** - can migrate workloads between orchestrators based on fit

### Negative

1. **Increased complexity** - managing two orchestrators instead of one
2. **Split monitoring** - requires federation and careful data source configuration
3. **Secret management divergence** - op-connect for Swarm, External Secrets for k8s
4. **Learning curve** - team must understand both k8s and Swarm paradigms
5. **Potential for inconsistency** - need strong governance to maintain standards

### Neutral

1. **Migration effort** - significant upfront work, but staged approach reduces risk
2. **Documentation burden** - more systems to document, but better clarity of purpose
3. **Disaster recovery** - need separate backup strategies for k8s PVCs and ZFS datasets

## Compliance with Constitution/Contracts

This decision aligns with:

- **Constitution Principle: Right Tool for the Job** - Using simpler orchestration where appropriate
- **Contract: Immutability via Git** - All compose files version-controlled
- **Contract: Secrets Never in Plain Text** - Continues ADR-0032 pattern with op-connect
- **Contract: Infrastructure as Code** - Bootstrap script and compose files are declarative
- **Requirement: Security** - Wazuh SIEM provides security monitoring
- **Requirement: Observability** - Enhanced with unified Grafana/Loki

## Review and Updates

This ADR will be reviewed:
- After Phase 3 completion (media stack migration)
- At 6-month intervals
- When TrueNAS Scale has major version updates
- If team size or workload characteristics change significantly

**Acceptance Criteria for Success:**
- Infrastructure uptime > 99.9% (measured over 3 months post-migration)
- Mean time to deploy new service < 15 minutes
- Team satisfaction with deployment workflow (survey post-migration)
- Operational incidents < 2 per month related to orchestration

## References

- [ADR-0032: 1Password Secrets Management](./ADR-0032-1password-secrets.md)
- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [TrueNAS Scale Documentation](https://www.truenas.com/docs/scale/)
- [Komodo Documentation](https://github.com/moghtech/komodo)
- [Prometheus Federation](https://prometheus.io/docs/prometheus/latest/federation/)
