# Implementation Plan: Backstage App Templating Platform

**Branch**: `001-backstage-app-templates` | **Date**: 2026-01-25 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-backstage-app-templates/spec.md`

## Summary

Implement Backstage with self-service app templating to enable operators to deploy containerized applications to the homelab cluster and NAS. Two primary workflows: (1) **GitOps Apps** - Backstage generates Kubernetes manifests with customizable storage, ingress/DNS, and backup patterns; commits to Git; Flux reconciles. (2) **NAS Apps** - Backstage submits deployment requests to Komodo for TrueNAS orchestration. Both workflows follow constitutional DNS intent boundaries and enforce configuration guardrails.

## Technical Context

**Language/Version**: Node.js 18+ (Backstage runs on TypeScript/Node)  
**Primary Dependencies**: 
- Backstage framework (core, plugins)
- Kubernetes client library (to interact with cluster APIs)
- Git client (to create branches/PRs - likely using CLI or octokit)
- YAML templating engine (for manifest generation - likely Handlebars, Nunjucks, or Helm-like templating)
- Authentik OIDC connector (for auth integration)

**Storage**: 
- Backstage catalog database (PostgreSQL or similar - determined by deployment choice)
- Git repository as source of truth (no separate data store needed for app requests beyond Git history)

**Testing**: 
- Jest (Backstage default)
- Supertest for API testing
- Manual E2E testing with cluster integration

**Target Platform**: Kubernetes cluster (Linux)

**Project Type**: Web application (Backstage frontend + backend)

**Performance Goals**: 
- Form submission to Git commit: <3 seconds
- PR creation to merge: <30 seconds (conditional auto-merge)
- Template rendering: <1 second
- Concurrent form submissions: 10+ simultaneous operators

**Constraints**: 
- Must not exceed Backstage resource footprint (pods fit in existing cluster)
- Git operations must respect rate limits (GitHub API)
- Manifest generation must be synchronous (user sees result immediately)
- No external API calls during manifest rendering (offline capability preferred)

**Scale/Scope**: 
- Initial: 1 GitOps template + 1 Komodo template
- ~10-15 apps deployed monthly (P1 phase)
- Expandable to 10+ templates over time

**Existing Integrations to Leverage**:
- Authentik (identity provider) - via OIDC
- Flux (GitOps reconciliation) - via Git push
- Longhorn (storage) - already deployed
- Volsync (backup) - already deployed
- Cloudflare Tunnel (ingress) - already configured
- ExternalDNS (DNS management) - already configured
- Komodo (NAS orchestration) - already deployed

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Homelab Constitution Principles** (from `constitution/constitution.md`):

1. ✅ **Management is Sacred and Boring**  
   *Assessment*: Backstage itself is a management tool; runs in cluster management namespace; restricted to authenticated operators only. No impact to sacred management network boundary.
   
2. ✅ **DNS Encodes Intent**  
   *Assessment*: **CRITICAL** - FR-011 explicitly enforces this. Internal apps → `*.internal.hypyr.space`, external apps → `*.hypyr.space`. Manifest generation rejects mismatched configurations. Stored in template rules.
   
3. ✅ **External Access is Identity-Gated**  
   *Assessment*: FR-001 requires Authentik authentication. All Backstage UI access gated. Generated manifests reference existing Cloudflare Tunnel annotations; Backstage generates Ingress but doesn't control tunnel itself.
   
4. ✅ **Routing Does Not Imply Permission**  
   *Assessment*: Backstage generates Service + Ingress resources; authorization remains with Kubernetes RBAC + Cloudflare Access policies. No circular dependency.
   
5. ✅ **Prefer Structural Safety Over Convention**  
   *Assessment*: Templates are hardcoded, not user-configurable. Operators select from pre-defined patterns (storage, ingress, backup). Invalid combinations rejected at form validation time, before Git operations.

**Governance Requirements** (from `docs/governance/`):

- ✅ CI gates must pass: Backstage-generated manifests must pass all existing gates (`check-helmrelease-template.sh`, `check-kustomize-build.sh`, `check-cross-env-refs.sh`, etc.)
- ✅ GitOps principle: All state in Git; Backstage is just a form UI layer; Flux remains the source of truth
- ✅ ADR-0005 (Agent Governance): This feature implements tooling that *enables* compliance, doesn't bypass it

**Compliance Status**: ✅ **PASS** - No conflicts with constitution or governance. Feature strengthens DNS intent enforcement and reduces manual error.

## Project Structure

### Documentation (this feature)

```text
specs/001-backstage-app-templates/
├── spec.md              # Feature specification (completed)
├── plan.md              # This file (implementation planning)
├── research.md          # Phase 0 output (technology research, dependencies)
├── data-model.md        # Phase 1 output (data schemas, API contracts)
├── contracts/           # Phase 1 output (API, template schemas, validation rules)
├── quickstart.md        # Phase 1 output (setup guide, getting started)
├── checklists/
│   └── requirements.md  # Quality validation checklist
└── tasks.md             # Phase 2 output (breakdown of implementation work)
```

### Source Code (repository root)

**Backstage Installation & Config**:
```text
kubernetes/clusters/<cluster>/namespaces/backstage/
├── backstage-deployment.yaml      # Backstage Pod + Service + Ingress
├── backstage-secrets.yaml          # GitHub PAT, Git SSH key, Authentik client secret
├── backstage-configmap.yaml        # app-config.yaml bundled as ConfigMap
├── postgres-pvc.yaml               # Database persistence (if applicable)
└── kustomization.yaml              # Namespace kustomization

# NOTE: Backstage helm chart installation should also be considered
# See: https://backstage.io/docs/deployment/k8s
```


## Implementation Phases

### Phase 0: Research & Dependencies

**Objective**: Resolve unknowns about Backstage scaffolder plugins, Git automation libraries, and manifest templating engines.

**Key Research Tasks**:
1. Backstage Scaffolder architecture - how to create custom templates, what hook capabilities exist
2. Git automation in Node.js - compare octokit (GitHub API) vs. nodegit vs. git CLI
3. YAML templating engines - Handlebars vs. Nunjucks vs. custom logic
4. Kubernetes manifest validation - kubernetes-models library, schema validation tooling
5. Authentik OIDC integration with Backstage - documented integration pattern
6. Conditional auto-merge implementation - GitHub branch protection rules vs. workflow automation

**Deliverable**: `research.md` - technology choices, decision rationale, code samples

---

### Phase 1: Design & API Contracts

**Objective**: Define data models, API schemas, and template structure; ensure contracts are testable.

**Key Design Tasks**:

1. **Data Models** (`data-model.md`):
   - App Request schema (form fields, validation rules)
   - Storage Pattern schema (template structure, variable bindings)
   - Ingress Pattern schema (Service/Ingress/ExternalDNS templates)
   - Backup Strategy schema (Volsync configuration options)
   - Komodo Request schema (NAS app submission format)

2. **API Contracts** (`contracts/`):
   - `scaffolder-form-schema.yaml` - Backstage form input definition (JSON Schema)
   - `manifest-generator-api.md` - Generator function inputs/outputs
   - `git-operations-contract.md` - Branch creation, commit, PR requirements
   - `validation-rules.md` - DNS naming enforcement, storage/ingress compatibility matrix
   - `komodo-api-contract.md` - Komodo webhook payload format

3. **Quick Start** (`quickstart.md`):
   - Local Backstage dev environment setup
   - How to run scaffolder template locally
   - How to test manifest generation
   - Deployment checklist (secrets, RBAC, etc.)

4. **Update Agent Context**:
   - Run `.specify/scripts/bash/update-agent-context.sh copilot`
   - Adds Backstage, scaffolder, YAML templating to agent knowledge
   - Preserves manual additions between markers

**Deliverable**: `data-model.md`, `contracts/`, `quickstart.md`, updated agent context

---

### Phase 2: Task Breakdown

**Objective**: Break implementation into discrete, testable, independently deployable tasks.

This is generated by the `/speckit.tasks` command (not part of this plan).

Expected task categories:
1. **Backstage Deployment** - install, configure, auth
2. **GitOps Template** - scaffolder template, manifest generator, Git hooks
3. **Komodo Template** - scaffolder template, API integration
4. **Form Validation** - DNS rules, storage/ingress compatibility
5. **Testing & Integration** - E2E tests with real cluster
6. **Documentation** - runbooks, troubleshooting, template customization guide

---

## Quality Gates

### Pre-Phase-1 Gate: Constitution Compliance

✅ **PASS** - See Constitution Check section above

### Pre-Implementation Gate: Technical Feasibility

- [ ] Research phase completed
- [ ] Backstage scaffolder can create custom templates (documented)
- [ ] Git operations library chosen (octokit vs. CLI)
- [ ] YAML templating engine selected
- [ ] Authentik OIDC integration pattern confirmed

### Pre-Deployment Gate: CI Validation

All generated manifests MUST pass existing repository gates:
- ✅ `check-helmrelease-template.sh` (if applicable)
- ✅ `check-kustomize-build.sh`
- ✅ `check-cross-env-refs.sh`
- ✅ `no-invariant-drift.sh`
- ✅ `check-no-plaintext-secrets.sh`

### Post-Deployment Gate: Success Criteria

Track metrics from `spec.md`:
1. Deployment velocity (< 5 min end-to-end)
2. Configuration accuracy (100% gates pass)
3. User adoption (3+ apps in first month)
4. DNS compliance (100% correct naming)

---

## Schedule Notes

- **Phase 0 (Research)**: ~2-3 days (parallel research tasks)
- **Phase 1 (Design)**: ~3-4 days (sequential design + contracts)
- **Phase 2 (Implementation)**: Task breakdown needed via `/speckit.tasks`

---

## Risk Mitigations

| Risk | Mitigation |
|------|-----------|
| Scaffolder complexity | Start with manual template, automate generation incrementally |
| Git API rate limits | Use octokit with exponential backoff; batch operations where possible |
| Manifest validation timing | Validate synchronously before any Git operations; user sees errors immediately |
| Backstage resource bloat | Use Backstage helm chart defaults; monitor pod resource usage |
| Komodo API instability | Implement retry logic + graceful error messages; NAS deployment is non-critical path |

---

## Related Documentation

- **Backstage Docs**: https://backstage.io/docs/
- **Scaffolder Plugin**: https://backstage.io/docs/features/software-catalog/software-templates
- **Homelab DNS Intent**: `constitution/constitution.md` - Principle #2
- **Existing Ingress Pattern**: `requirements/ingress/spec.md` - Cloudflare Tunnel configuration
- **Storage Patterns**: `requirements/storage/spec.md` - Longhorn, NAS, S3 options
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [REMOVE IF UNUSED] Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure: feature modules, UI flows, platform tests]
```

**Structure Decision**: [Document the selected structure and reference the real
directories captured above]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
