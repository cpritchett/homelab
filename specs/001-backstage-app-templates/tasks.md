# Implementation Tasks: Backstage App Templating Platform

**Phase**: 2 (Task Breakdown)
**Date**: 2026-01-25
**Status**: Ready for Implementation
**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Research**: [research.md](research.md)

---

## Overview

This document breaks down the Backstage App Templating Platform implementation into discrete, testable, independently deployable tasks. Tasks are organized by functional area and prioritized based on user story dependencies.

**Implementation Order**:
1. Infrastructure (Backstage deployment, auth)
2. GitOps Template (core workflow)
3. Manifest Generation (storage, ingress, backup patterns)
4. Git Operations (branch, commit, PR, auto-merge)
5. Validation & Safety (schema validation, DNS enforcement)
6. Komodo Template (NAS workflow)
7. Documentation & Runbooks

---

## Task Legend

| Symbol | Meaning |
|--------|---------|
| `[ ]` | Not started |
| `[~]` | In progress |
| `[x]` | Complete |
| `[!]` | Blocked |
| **P1** | Must-have for MVP |
| **P2** | Important but can defer |
| **P3** | Nice-to-have |

---

## Phase 1: Infrastructure & Backstage Deployment

### Task 1.1: Create Backstage Kubernetes Namespace Structure [P1]

**Description**: Create the namespace and base kustomization for Backstage deployment following existing homelab patterns.

**Acceptance Criteria**:
- [x] Directory created: `kubernetes/clusters/homelab/apps/backstage/`
- [x] `namespace.yaml` created with proper labels
- [x] `kustomization.yaml` references all component manifests
- [x] Namespace integrates with existing apps kustomization

**Files to Create**:
```
kubernetes/clusters/homelab/apps/backstage/
├── namespace.yaml
├── kustomization.yaml
└── backstage/
    ├── kustomization.yaml
    └── app/
        ├── kustomization.yaml
        ├── helmrelease.yaml    # or deployment.yaml
        ├── externalsecret.yaml
        └── pvc.yaml            # for PostgreSQL
```

**Dependencies**: None
**Estimated Effort**: Small

---

### Task 1.2: Deploy Backstage via Helm Chart [P1]

**Description**: Create HelmRelease for Backstage backend using the official Backstage Helm chart.

**Acceptance Criteria**:
- [x] HelmRelease created referencing Backstage chart
- [x] Resource limits set (100m/256Mi requests, 500m/512Mi limits)
- [x] Health probes configured
- [x] Pod starts and reports healthy

**Configuration Points**:
- Image: `ghcr.io/backstage/backend:v1.31.0` (or latest stable)
- Port: 7007
- Ingress: `backstage.in.hypyr.space`

**Dependencies**: Task 1.1
**Estimated Effort**: Medium

---

### Task 1.3: Configure Authentik OIDC Integration [P1]

**Description**: Set up OIDC authentication with existing Authentik instance.

**Acceptance Criteria**:
- [x] Authentik application created for Backstage (manual in Authentik UI)
- [x] ExternalSecret created for client ID/secret
- [x] Backstage `app-config.yaml` configured with OIDC provider
- [x] User can log in via Authentik and access Backstage UI
- [x] Operator identity available in session for audit logging

**Configuration**:
```yaml
auth:
  providers:
    oidc:
      production:
        metadataUrl: https://auth.in.hypyr.space/application/o/backstage/.well-known/openid-configuration
        clientId: ${AUTHENTIK_CLIENT_ID}
        clientSecret: ${AUTHENTIK_CLIENT_SECRET}
```

**Dependencies**: Task 1.2
**Estimated Effort**: Medium

---

### Task 1.4: Configure GitHub Integration [P1]

**Description**: Set up GitHub integration for Git operations (read repo, create branches, open PRs).

**Acceptance Criteria**:
- [x] GitHub PAT created with `repo` scope (stored in 1Password or similar)
- [x] ExternalSecret created referencing PAT
- [x] Backstage `app-config.yaml` configured with GitHub integration
- [x] Backstage can list repositories and read files from homelab repo

**Configuration**:
```yaml
integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}
```

**Dependencies**: Task 1.2
**Estimated Effort**: Small

---

### Task 1.5: Create Backstage Ingress (Internal) [P1]

**Description**: Expose Backstage on internal DNS following constitutional DNS intent.

**Acceptance Criteria**:
- [x] Ingress created with host `backstage.in.hypyr.space`
- [x] Service type ClusterIP pointing to Backstage pod
- [x] DNS resolves internally (verify with `nslookup`)
- [x] UI accessible at https://backstage.in.hypyr.space

**Dependencies**: Task 1.2
**Estimated Effort**: Small

---

### Task 1.6: Verify Backstage Base Installation [P1]

**Description**: End-to-end verification that Backstage is running, accessible, and authenticated.

**Acceptance Criteria**:
- [x] Navigate to https://backstage.in.hypyr.space
- [ ] Redirected to Authentik login (requires deployment + Authentik app config)
- [ ] After login, Backstage catalog visible (requires deployment)
- [ ] No errors in Backstage backend logs (requires deployment)
- [x] CI gates pass for all new manifests

**Test Script**:
```bash
# Verify deployment
kubectl -n backstage rollout status deployment/backstage

# Check logs for errors
kubectl -n backstage logs -f deployment/backstage | grep -i error

# Test ingress
curl -k https://backstage.in.hypyr.space/health
```

**Dependencies**: Tasks 1.1-1.5
**Estimated Effort**: Small

---

## Phase 2: GitOps App Template - Form Definition

### Task 2.1: Create Scaffolder Template Directory Structure [P1]

**Description**: Set up the template directory structure for the GitOps app deployment template.

**Acceptance Criteria**:
- [x] Directory created in Backstage app: `scaffolder-templates/gitops-app-template/`
- [x] `template.yaml` with metadata (name, title, description, tags)
- [x] `skeleton/` directory for template fragments
- [ ] Template registered in Backstage catalog (requires deployment)

**Files**:
```
backstage/
└── scaffolder-templates/
    └── gitops-app-template/
        ├── template.yaml
        └── skeleton/
            ├── deployment.yaml.hbs
            ├── service.yaml.hbs
            ├── ingress.yaml.hbs
            ├── pvc-longhorn.yaml.hbs
            ├── pvc-nfs.yaml.hbs
            └── volsync.yaml.hbs
```

**Dependencies**: Task 1.6
**Estimated Effort**: Small

---

### Task 2.2: Define Application Details Form Step [P1]

**Description**: Create JSON Schema for the first form step: app name, container image, namespace.

**Acceptance Criteria**:
- [x] `appName` field with regex validation (`^[a-z0-9]([-a-z0-9]*[a-z0-9])?$`)
- [x] `containerImage` field with placeholder text
- [x] `namespace` field with default to app name
- [x] Form renders in Backstage UI without errors

**Schema**:
```yaml
parameters:
  - title: Application Details
    required: [appName, containerImage]
    properties:
      appName:
        type: string
        title: App Name
        pattern: '^[a-z0-9]([-a-z0-9]*[a-z0-9])?$'
        description: Lowercase alphanumeric with hyphens
      containerImage:
        type: string
        title: Container Image
        description: Full image URL (e.g., ghcr.io/owner/app:v1.0.0)
      namespace:
        type: string
        title: Namespace
        default: ""
        description: Defaults to app name if empty
```

**Dependencies**: Task 2.1
**Estimated Effort**: Small

---

### Task 2.3: Define Storage Pattern Form Step [P1]

**Description**: Create JSON Schema for storage pattern selection with conditional fields.

**Acceptance Criteria**:
- [x] `storagePattern` enum: ephemeral, longhorn-persistent, nas-mount, s3-external
- [x] `storageSize` field (visible for longhorn/nas)
- [x] `nasEndpoint` dropdown (visible for nas-mount)
- [x] `nasSubpath` field (visible for nas-mount)
- [x] `s3Bucket` and `s3Region` fields (visible for s3-external)
- [x] Conditional visibility works in UI

**Schema**:
```yaml
- title: Storage Configuration
  properties:
    storagePattern:
      type: string
      title: Storage Pattern
      enum: [ephemeral, longhorn-persistent, nas-mount, s3-external]
      default: ephemeral
    storageSize:
      type: string
      title: Storage Size (GB)
      pattern: '^[0-9]{1,4}$'
      default: "10"
      ui:hidden: '{{ storagePattern != "longhorn-persistent" && storagePattern != "nas-mount" }}'
    nasEndpoint:
      type: string
      title: NAS Endpoint
      enum: ["nfs://nas.internal:2049", "nfs://nas-backup.internal:2049"]
      ui:hidden: '{{ storagePattern != "nas-mount" }}'
    nasSubpath:
      type: string
      title: NAS Subpath
      description: e.g., /mnt/apps/myapp
      ui:hidden: '{{ storagePattern != "nas-mount" }}'
    s3Bucket:
      type: string
      title: S3 Bucket
      ui:hidden: '{{ storagePattern != "s3-external" }}'
```

**Dependencies**: Task 2.2
**Estimated Effort**: Medium

---

### Task 2.4: Define Ingress Pattern Form Step [P1]

**Description**: Create JSON Schema for ingress/DNS pattern selection.

**Acceptance Criteria**:
- [x] `ingressPattern` enum: internal-only, external-via-tunnel
- [x] Form shows DNS preview based on selection
- [x] Default is internal-only

**Schema**:
```yaml
- title: Ingress & DNS Configuration
  properties:
    ingressPattern:
      type: string
      title: Ingress Pattern
      enum: [internal-only, external-via-tunnel]
      default: internal-only
      enumNames:
        - "Internal Only (*.in.hypyr.space)"
        - "External via Tunnel (*.hypyr.space)"
```

**Dependencies**: Task 2.2
**Estimated Effort**: Small

---

### Task 2.5: Define Backup Strategy Form Step [P1]

**Description**: Create JSON Schema for backup strategy selection.

**Acceptance Criteria**:
- [x] `backupStrategy` enum: none, volsync-snapshots
- [x] Retention days field (visible for volsync)
- [x] Default is none

**Schema**:
```yaml
- title: Backup Strategy
  properties:
    backupStrategy:
      type: string
      title: Backup Strategy
      enum: [none, volsync-snapshots]
      default: none
    retentionDays:
      type: number
      title: Retention Days
      default: 30
      ui:hidden: '{{ backupStrategy != "volsync-snapshots" }}'
```

**Dependencies**: Task 2.2
**Estimated Effort**: Small

---

### Task 2.6: Verify Form Renders Correctly [P1]

**Description**: End-to-end test that the complete form renders and validates in Backstage UI.

**Acceptance Criteria**:
- [ ] Navigate to "Create" in Backstage
- [ ] "Deploy GitOps App" template appears
- [x] All form steps render without errors
- [x] Conditional fields show/hide correctly
- [x] Validation errors appear for invalid input
- [x] Can complete form to final step

**Dependencies**: Tasks 2.1-2.5
**Estimated Effort**: Small

---

## Phase 3: Manifest Generation Engine

### Task 3.1: Create Handlebars Template for Deployment [P1]

**Description**: Create Handlebars template that generates Kubernetes Deployment manifest.

**Acceptance Criteria**:
- [ ] Template file: `skeleton/deployment.yaml.hbs`
- [ ] Generates valid Deployment with:
  - App name, namespace
  - Container image
  - Resource requests/limits
  - Volume mounts (based on storage pattern)
  - Labels and selectors
- [ ] Passes `kubernetes-models` validation

**Template Structure**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{appName}}
  namespace: {{namespace}}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{appName}}
  template:
    metadata:
      labels:
        app: {{appName}}
    spec:
      containers:
        - name: {{appName}}
          image: {{containerImage}}
          ports:
            - containerPort: 8080
          {{#if hasVolume}}
          volumeMounts:
            - name: app-data
              mountPath: /data
          {{/if}}
      {{#if hasVolume}}
      volumes:
        {{> volumePartial}}
      {{/if}}
```

**Dependencies**: Task 2.6
**Estimated Effort**: Medium

---

### Task 3.2: Create Handlebars Template for Service [P1]

**Description**: Create Handlebars template that generates Kubernetes Service manifest.

**Acceptance Criteria**:
- [x] Template file: `skeleton/service.yaml.hbs`
- [x] Generates ClusterIP Service
- [x] Port configuration matches Deployment

**Dependencies**: Task 3.1
**Estimated Effort**: Small

---

### Task 3.3: Create Handlebars Templates for Ingress (Internal & External) [P1]

**Description**: Create Handlebars templates for both ingress patterns.

**Acceptance Criteria**:
- [ ] `skeleton/ingress-internal.yaml.hbs` with:
  - Host: `{{appName}}.in.hypyr.space`
  - IngressClassName: nginx
- [ ] `skeleton/ingress-external.yaml.hbs` with:
  - Host: `{{appName}}.hypyr.space`
  - ExternalDNS annotations for Cloudflare
- [ ] Correct template selected based on `ingressPattern`

**Dependencies**: Task 3.2
**Estimated Effort**: Medium

---

### Task 3.4: Create Handlebars Templates for Storage Patterns [P1]

**Description**: Create Handlebars templates for each storage pattern.

**Acceptance Criteria**:
- [x] Ephemeral storage handled in deployment template (emptyDir)
- [x] `skeleton/pvc-longhorn.yaml.hbs` - PVC with Longhorn StorageClass
- [x] `skeleton/pvc-nfs.yaml.hbs` - PV + PVC with NFS configuration
- [ ] S3 external storage - Secret + env vars (deferred)
- [x] Each template generates valid Kubernetes resources

**Dependencies**: Task 3.1
**Estimated Effort**: Medium

---

### Task 3.5: Create Handlebars Template for Volsync Backup [P2]

**Description**: Create Handlebars template for Volsync ReplicationDestination.

**Acceptance Criteria**:
- [ ] `skeleton/volsync.yaml.hbs`
- [ ] Generates ReplicationDestination with:
  - Daily schedule (configurable)
  - Restic backend
  - Source PVC reference
- [ ] Only generated when `backupStrategy = volsync-snapshots`

**Dependencies**: Task 3.4
**Estimated Effort**: Small

---

### Task 3.6: Create Manifest Generator Action [P1]

**Description**: Implement custom Scaffolder action that orchestrates template rendering.

**Acceptance Criteria**:
- [x] TypeScript action stub: `src/actions/generateManifests.ts`
- [ ] Receives form input as parameters
- [ ] Renders correct templates based on selections
- [ ] Outputs file paths for Git operations
- [ ] Logs template choices for audit trail
- [ ] Unit tests pass

**Implementation**:
```typescript
export const generateManifestsAction = createTemplateAction({
  id: 'custom:generate-manifests',
  schema: {
    input: {
      appName: z.string(),
      containerImage: z.string(),
      namespace: z.string(),
      storagePattern: z.enum(['ephemeral', 'longhorn-persistent', 'nas-mount', 's3-external']),
      ingressPattern: z.enum(['internal-only', 'external-via-tunnel']),
      backupStrategy: z.enum(['none', 'volsync-snapshots']),
      // ... additional fields
    }
  },
  async handler(ctx) {
    // Render templates with Handlebars
    // Write to output directory
    // Return file list
  }
});
```

**Dependencies**: Tasks 3.1-3.5
**Estimated Effort**: Large

---

### Task 3.7: Create Kustomization Generator [P1]

**Description**: Generate `kustomization.yaml` that references all created manifests.

**Acceptance Criteria**:
- [x] `skeleton/kustomization.yaml.hbs`
- [x] Lists all generated resources
- [x] Follows existing homelab kustomization patterns
- [x] Integrates with parent namespace kustomization

**Dependencies**: Task 3.6
**Estimated Effort**: Small

---

### Task 3.8: Verify Manifest Generation End-to-End [P1]

**Description**: Test complete manifest generation with all pattern combinations.

**Test Matrix**:
| Storage | Ingress | Backup | Expected Files |
|---------|---------|--------|----------------|
| ephemeral | internal | none | deployment, service, ingress |
| longhorn | internal | none | deployment, service, ingress, pvc |
| longhorn | external | volsync | deployment, service, ingress, pvc, volsync |
| nas | internal | none | deployment, service, ingress, pv, pvc |
| s3 | external | none | deployment, service, ingress, secret |

**Acceptance Criteria**:
- [ ] All combinations generate valid manifests
- [ ] All manifests pass `kubectl apply --dry-run`
- [ ] All manifests pass existing CI gates

**Dependencies**: Task 3.7
**Estimated Effort**: Medium

---

## Phase 4: Git Operations & Auto-Merge

### Task 4.1: Implement Branch Creation Action [P1]

**Description**: Create Scaffolder action that creates feature branch from main.

**Acceptance Criteria**:
- [ ] Branch name format: `feat/app/{{appName}}-{{shortHash}}`
- [ ] Uses Octokit for GitHub API
- [ ] Handles existing branch (append suffix or error)
- [ ] Returns branch name for subsequent steps

**Dependencies**: Task 1.4
**Estimated Effort**: Medium

---

### Task 4.2: Implement Commit Action [P1]

**Description**: Create Scaffolder action that commits generated manifests.

**Acceptance Criteria**:
- [ ] Commit message format: `feat(app): add {{appName}}`
- [ ] Adds all generated files to commit
- [ ] Uses conventional commit format
- [ ] Returns commit SHA

**Dependencies**: Task 4.1
**Estimated Effort**: Medium

---

### Task 4.3: Implement Pull Request Action [P1]

**Description**: Create Scaffolder action that opens PR against main branch.

**Acceptance Criteria**:
- [ ] PR title: `feat: deploy {{appName}}`
- [ ] PR body includes:
  - App configuration summary
  - Storage pattern selected
  - Ingress pattern selected
  - Backup strategy
  - Operator identity
- [ ] Returns PR number and URL

**Dependencies**: Task 4.2
**Estimated Effort**: Medium

---

### Task 4.4: Implement Conditional Auto-Merge Action [P1]

**Description**: Create Scaffolder action that auto-merges if gates pass and no high-risk changes.

**Acceptance Criteria**:
- [ ] Waits for CI checks to complete (with timeout)
- [ ] If all checks pass AND not high-risk: merge
- [ ] If high-risk detected: add comment, skip merge
- [ ] High-risk criteria:
  - External ingress selected
  - New ExternalDNS annotation
  - Changes to management namespace

**Implementation**:
```typescript
async function shouldAutoMerge(prNumber: number): Promise<boolean> {
  const checks = await octokit.checks.listForRef(...);
  const allPassed = checks.every(c => c.status === 'completed' && c.conclusion === 'success');

  const files = await octokit.pulls.listFiles(...);
  const hasExternalIngress = files.some(f => f.patch?.includes('hypyr.space') && !f.patch?.includes('in.hypyr.space'));

  return allPassed && !hasExternalIngress;
}
```

**Dependencies**: Task 4.3
**Estimated Effort**: Large

---

### Task 4.5: Add High-Risk Change Detection Workflow [P1]

**Description**: Create GitHub Actions workflow to detect and flag high-risk PRs.

**Acceptance Criteria**:
- [ ] Workflow file: `.github/workflows/flag-high-risk-prs.yaml`
- [ ] Triggers on PR creation/update
- [ ] Detects external ingress, DNS changes, secrets
- [ ] Adds comment and label if high-risk
- [ ] Works with existing CI gates

**Dependencies**: Task 4.4
**Estimated Effort**: Medium

---

### Task 4.6: Verify Git Operations End-to-End [P1]

**Description**: Test complete Git workflow from form submission to merged PR.

**Acceptance Criteria**:
- [ ] Submit form with valid inputs
- [ ] Branch created automatically
- [ ] Manifests committed
- [ ] PR opened with correct description
- [ ] CI gates run and pass
- [ ] Auto-merge occurs (for low-risk)
- [ ] High-risk PRs flagged with comment

**Dependencies**: Tasks 4.1-4.5
**Estimated Effort**: Medium

---

## Phase 5: Validation & Safety

### Task 5.1: Implement Kubernetes Schema Validation [P1]

**Description**: Add manifest validation using `kubernetes-models` library.

**Acceptance Criteria**:
- [x] Validation logic stub created
- [ ] Validates Deployment, Service, Ingress, PVC schemas
- [ ] Runs before Git operations
- [ ] Returns clear error messages to user
- [ ] Blocks submission on validation failure

**Dependencies**: Task 3.6
**Estimated Effort**: Medium

---

### Task 5.2: Implement DNS Intent Validation (FR-011) [P1]

**Description**: Enforce constitutional DNS naming rules.

**Acceptance Criteria**:
- [x] Internal apps MUST use `*.in.hypyr.space`
- [x] External apps MUST use `*.hypyr.space` (not internal)
- [x] Validation logic implemented in validateManifests.ts
- [ ] Integration with template workflow
- [ ] Clear error message on violation

**Validation Logic**:
```typescript
function validateDNSIntent(ingressPattern: string, hostname: string): void {
  if (ingressPattern === 'internal-only' && !hostname.endsWith('.in.hypyr.space')) {
    throw new Error('Internal apps must use .in.hypyr.space domain');
  }
  if (ingressPattern === 'external-via-tunnel' && hostname.includes('.in.')) {
    throw new Error('External apps cannot use .in domain');
  }
}
```

**Dependencies**: Task 5.1
**Estimated Effort**: Small

---

### Task 5.3: Implement Container Image Validation [P1]

**Description**: Best-effort validation that container image exists.

**Acceptance Criteria**:
- [ ] Query registry for image existence (if public)
- [ ] For private registries: skip validation, warn user
- [ ] Non-blocking: warn but allow submission
- [ ] Log validation result for audit

**Dependencies**: Task 3.6
**Estimated Effort**: Medium

---

### Task 5.4: Implement Subpath Validation (NAS) [P1]

**Description**: Validate NAS subpath does not contain path traversal.

**Acceptance Criteria**:
- [ ] Reject paths containing `..`
- [ ] Reject paths not starting with `/`
- [ ] Clear error message on violation

**Dependencies**: Task 2.3
**Estimated Effort**: Small

---

### Task 5.5: Implement Audit Logging (FR-012) [P1]

**Description**: Log all template submissions for audit trail.

**Acceptance Criteria**:
- [ ] Log includes: app name, operator ID, timestamp
- [ ] Log includes: storage/ingress/backup choices
- [ ] Log includes: PR number (if created)
- [ ] Logs written to Backstage backend log output
- [ ] Logs follow structured format (JSON)

**Dependencies**: Task 4.3
**Estimated Effort**: Small

---

### Task 5.6: Verify All Validation Rules [P1]

**Description**: Test all validation scenarios.

**Test Cases**:
- [ ] Invalid app name (uppercase) → form error
- [ ] Invalid container image → warning
- [x] NAS subpath with `..` → form error
- [x] Internal app with external domain → validation error
- [x] External app with internal domain → validation error
- [ ] All valid inputs → submission succeeds

**Dependencies**: Tasks 5.1-5.5
**Estimated Effort**: Medium

---

## Phase 6: Komodo NAS Template

### Task 6.1: Create Komodo Template Directory Structure [P2]

**Description**: Set up template directory for NAS app deployment.

**Acceptance Criteria**:
- [ ] Directory: `scaffolder-templates/komodo-app-template/`
- [ ] `template.yaml` with metadata
- [ ] Template registered in Backstage catalog

**Dependencies**: Task 1.6
**Estimated Effort**: Small

---

### Task 6.2: Define Komodo Form Schema [P2]

**Description**: Create JSON Schema for Komodo deployment form.

**Acceptance Criteria**:
- [ ] `appName` field
- [ ] `appVersion` field
- [ ] `storageLocation` dropdown (TrueNAS datasets)
- [ ] App-specific configuration (key-value pairs)

**Dependencies**: Task 6.1
**Estimated Effort**: Small

---

### Task 6.3: Implement Komodo API Action [P2]

**Description**: Create Scaffolder action that submits request to Komodo API.

**Acceptance Criteria**:
- [ ] Constructs Komodo-compatible payload
- [ ] Sends POST request to Komodo webhook
- [ ] Handles success/failure response
- [ ] Returns deployment status

**Dependencies**: Task 6.2
**Estimated Effort**: Medium

---

### Task 6.4: Verify Komodo Template End-to-End [P2]

**Description**: Test Komodo deployment workflow.

**Acceptance Criteria**:
- [ ] Submit form with valid inputs
- [ ] Komodo API receives request
- [ ] App appears in Komodo dashboard
- [ ] Deployment completes on NAS

**Dependencies**: Task 6.3
**Estimated Effort**: Medium

---

## Phase 7: Documentation & Runbooks

### Task 7.1: Create Operator Runbook [P1]

**Description**: Document how operators use Backstage to deploy apps.

**Acceptance Criteria**:
- [ ] Step-by-step guide for GitOps deployment
- [ ] Storage pattern selection guidance
- [ ] Ingress pattern selection guidance
- [ ] Troubleshooting common errors
- [ ] Located in Backstage catalog (linked from template)

**Dependencies**: Task 4.6
**Estimated Effort**: Medium

---

### Task 7.2: Create Template Customization Guide [P2]

**Description**: Document how to add new templates or patterns.

**Acceptance Criteria**:
- [ ] How to add new storage pattern
- [ ] How to add new ingress pattern
- [ ] How to modify form schema
- [ ] Testing procedures

**Dependencies**: Task 3.8
**Estimated Effort**: Medium

---

### Task 7.3: Create Troubleshooting Runbook [P1]

**Description**: Document common issues and resolutions.

**Acceptance Criteria**:
- [ ] Template not appearing → catalog refresh
- [ ] Manifest generation fails → validation errors
- [ ] Git operations fail → token permissions
- [ ] Auto-merge fails → high-risk detection
- [ ] DNS not resolving → ExternalDNS logs

**Dependencies**: Task 4.6
**Estimated Effort**: Small

---

### Task 7.4: Update Repository README [P2]

**Description**: Add Backstage section to repository documentation.

**Acceptance Criteria**:
- [ ] Brief overview of Backstage purpose
- [ ] Link to operator runbook
- [ ] Link to template customization guide
- [ ] Access URL and login instructions

**Dependencies**: Task 7.1
**Estimated Effort**: Small

---

## Success Metrics Tracking

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Deployment Velocity | < 5 min | Timestamp: form submit → pod running |
| Configuration Accuracy | 100% gates pass | CI gate results on PRs |
| User Adoption | 3+ apps/month | Count merged PRs with `feat/app/` prefix |
| Template Reusability | 0 template modifications | Count template changes after initial release |
| Audit Trail | 100% logged | Log query for template submissions |
| DNS Compliance | 100% correct | Grep Ingress hosts for correct patterns |

---

## Risk Mitigation Checkpoints

### Checkpoint 1: After Phase 1 (Infrastructure)
- [ ] Backstage accessible and authenticated
- [ ] No errors in pod logs
- [ ] CI gates pass for new manifests

### Checkpoint 2: After Phase 3 (Manifest Generation)
- [ ] All storage patterns generate valid YAML
- [ ] All ingress patterns generate valid YAML
- [ ] Manifests pass `kubectl apply --dry-run`

### Checkpoint 3: After Phase 4 (Git Operations)
- [ ] PRs created automatically
- [ ] Auto-merge works for low-risk changes
- [ ] High-risk changes flagged correctly

### Checkpoint 4: After Phase 5 (Validation)
- [ ] Invalid inputs blocked at form level
- [ ] DNS intent violations caught
- [ ] Audit logs present

---

## Task Dependencies Graph

```
Phase 1: Infrastructure
  1.1 → 1.2 → 1.3 → 1.5 → 1.6
              ↓
            1.4

Phase 2: Form Definition
  1.6 → 2.1 → 2.2 → 2.3
                ↓
              2.4 → 2.5 → 2.6

Phase 3: Manifest Generation
  2.6 → 3.1 → 3.2 → 3.3
              ↓
            3.4 → 3.5 → 3.6 → 3.7 → 3.8

Phase 4: Git Operations
  1.4 → 4.1 → 4.2 → 4.3 → 4.4 → 4.5 → 4.6

Phase 5: Validation
  3.6 → 5.1 → 5.2
          ↓
        5.3 → 5.4 → 5.5 → 5.6

Phase 6: Komodo (parallel after 1.6)
  1.6 → 6.1 → 6.2 → 6.3 → 6.4

Phase 7: Documentation (after 4.6)
  4.6 → 7.1 → 7.2 → 7.3 → 7.4
```

---

## Summary

**Total Tasks**: 35
**P1 (Must-have)**: 29
**P2 (Important)**: 6

**Critical Path**: Phases 1-4 (Infrastructure → Form → Generation → Git)

**Parallelizable**:
- Phase 6 (Komodo) can run parallel to Phases 3-5
- Tasks within Phase 3 (templates) can be parallelized
- Documentation (Phase 7) can start after Phase 4

**First Deliverable**: After Phase 4, operators can deploy apps via Backstage with auto-merge.
