# Feature Specification: Backstage App Templating Platform

**Feature Branch**: `001-backstage-app-templates`  
**Created**: 2026-01-25  
**Status**: Draft  
**Input**: User description: "Implement Backstage for app templating with support for GitOps apps with customizable storage patterns, ingress/DNS configuration, and backup options. Include separate workflow for NAS apps via Komodo."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deploy GitOps App via Backstage Template (Priority: P1)

An operator discovers a containerized application they want to run in the homelab. They use Backstage to submit a request specifying the app details, storage needs, and network exposure. The system generates proper Kubernetes manifests following GitOps patterns, commits them to the repository, and Flux synchronizes the deployment.

**Why this priority**: This is the core MVP value proposition. Without this, Backstage provides no operational benefit. It directly enables self-service app deployment.

**Independent Test**: An operator can submit a complete app request and verify that Kubernetes resources appear in `kubernetes/clusters` within 5 minutes and the app becomes healthy in the cluster.

**Acceptance Scenarios**:

1. **Given** an operator accessing Backstage with valid credentials, **When** they select the "Deploy GitOps App" template, **Then** a multi-step form appears with fields for app name, container image, storage pattern, ingress requirements, and backup strategy.

2. **Given** an operator completing the form with all required fields, **When** they submit the request, **Then** a Git branch is created with generated Kubernetes manifests in the correct namespace structure, properly formatted YAML, and valid against schema.

3. **Given** valid manifests are committed to a feature branch, **When** a pull request is opened, **Then** CI gates validate the submission and the PR is mergeable if all checks pass.

4. **Given** a merged pull request, **When** Flux reconciles the repository, **Then** the app's Kubernetes Deployment, Service, and PersistentVolumeClaim (if needed) are created and become Ready within 2 minutes.

---

### User Story 2 - Configure Storage Pattern Selection (Priority: P1)

The operator selects from pre-defined storage patterns (ephemeral, Longhorn persistent, NAS mount, S3 external) during app creation. The template automatically generates appropriate PVC, StorageClass references, or volume mounts matching the chosen pattern.

**Why this priority**: Storage configuration is mandatory for most apps. Without this, templates are incomplete and ops must manually edit manifests. This is one of the core pain points the user mentioned.

**Independent Test**: Each storage pattern option generates valid Kubernetes manifests with correct storage configuration. Operator can select different patterns and inspect the resulting YAML before submitting.

**Acceptance Scenarios**:

1. **Given** the storage pattern selection step in the template, **When** an operator selects "Longhorn Persistent", **Then** a PersistentVolumeClaim with Longhorn StorageClass is generated.

2. **Given** the storage pattern selection step, **When** an operator selects "NAS Mount", **Then** a dropdown of pre-configured NAS endpoints appears, operator selects one, specifies a subpath (e.g., `/mnt/apps/<app-name>`), and the NFS volume mount is generated with the selected endpoint and subpath.

3. **Given** the storage pattern selection step, **When** an operator selects "Ephemeral", **Then** an emptyDir volume is generated (no PVC).

4. **Given** the storage pattern selection step, **When** an operator selects "S3 External", **Then** environment variables for S3 bucket endpoint are templated (credentials injected via External Secrets operator).

---

### User Story 3 - Configure Ingress and DNS Pattern (Priority: P1)

The operator chooses whether the app should be exposed internally (internal DNS + ClusterIP) or externally (public DNS + Cloudflare Tunnel). The template generates appropriate Ingress, Service, and ExternalDNS configuration matching the constitutional DNS intent rules.

**Why this priority**: Ingress/DNS configuration is mandatory. Incorrect configuration violates the constitution's DNS intent principle. This is one of the core requirements the user mentioned.

**Independent Test**: Each ingress pattern generates valid Ingress resources, proper DNS names (internal vs. external), and respects the constitutional DNS boundaries. Operator can preview generated Ingress before submission.

**Acceptance Scenarios**:

1. **Given** the ingress pattern selection step, **When** an operator selects "Internal Only", **Then** a Service of type ClusterIP and an Ingress with internal hostname are generated (e.g., `app-name.internal.hypyr.space`).

2. **Given** the ingress pattern selection step, **When** an operator selects "External via Tunnel", **Then** a Service of type ClusterIP, an Ingress with public hostname are generated (e.g., `app-name.hypyr.space`), and an ExternalDNS annotation for Cloudflare is added.

3. **Given** an external ingress selection, **When** the app is deployed, **Then** DNS resolution works from outside the network via Cloudflare Tunnel (assuming tunnel is active).

4. **Given** an internal ingress selection, **When** the app is deployed, **Then** DNS resolution only works from within the cluster/management network.

---

### User Story 4 - Configure Backup Strategy (Priority: P2)

The operator selects a backup strategy (none, Volsync snapshots, S3 backup, or [NEEDS CLARIFICATION: TrueNAS native snapshots?]). The template generates appropriate backup configuration resources.

**Why this priority**: Backup is important for data protection but not all apps require it. Some operators may choose "none" deliberately. This enables self-service backup configuration but doesn't block deployment if omitted.

**Independent Test**: Each backup strategy option generates valid backup configuration. Operator can see backup schedule and retention policies before submission.

**Acceptance Scenarios**:

1. **Given** the backup strategy selection step, **When** an operator selects "None", **Then** no backup resources are generated.

2. **Given** the backup strategy selection step, **When** an operator selects "Volsync Snapshots", **Then** a ReplicationDestination or ReplicationSource resource is generated with daily snapshot schedule.

3. **Given** Volsync Snapshots is selected, **When** the app is deployed, **Then** a ReplicationDestination resource is created with daily snapshot schedule configured to use the existing Volsync backend (destination determined by cluster configuration).

---

### User Story 5 - Deploy NAS App via Komodo Workflow (Priority: P2)

A separate workflow allows deploying applications directly to NAS (TrueNAS) via Komodo orchestration. The operator specifies the app, configuration, and storage location. Komodo handles deployment and lifecycle management.

**Why this priority**: This addresses the secondary use case for NAS-hosted apps. It's valuable but separate from the core GitOps workflow. Should be independently deployable.

**Independent Test**: An operator can submit a Komodo app request and verify the app is deployed to NAS via Komodo's dashboard within 5 minutes.

**Acceptance Scenarios**:

1. **Given** an operator selecting the "Deploy NAS App" template, **When** they submit the form, **Then** a Komodo deployment request is created with the specified app configuration.

2. **Given** a valid Komodo request, **When** Komodo processes it, **Then** the app is deployed to NAS with configured storage and network access.

---

### Edge Cases

- What happens when an operator requests an app image that doesn't exist (e.g., typo in image name)? → System should validate image availability (pull attempt in non-prod or image registry query) before committing manifests.
- What happens when requested storage quota exceeds available capacity on chosen backend? → System should estimate storage requirements and warn if quota seems high; deployment proceeds but may fail at runtime.
- What happens when an operator requests internal-only ingress for an app that's already exposed externally? → System should warn about duplicate exposure; manifests generated as requested (no automatic remediation).
- What happens when Volsync backend is unavailable? → Form validation warns user; deployment proceeds but Volsync ReplicationDestination may fail to sync until backend recovers.
- What happens when Komodo deployment fails? → Komodo reports error status; user can retry from Komodo dashboard directly or resubmit via Backstage.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Backstage installation MUST be deployed in the homelab cluster with authentication via Authentik (leveraging existing identity provider).

- **FR-002**: System MUST provide a "Deploy GitOps App" template that generates Kubernetes manifests (Deployment, Service, ConfigMap, optional PVC) in proper directory structure (`kubernetes/clusters/<cluster-name>/namespaces/<namespace>/`).

- **FR-003**: System MUST support four storage pattern options: Ephemeral (emptyDir), Longhorn Persistent (PVC), NAS Mount (NFS), S3 External (environment variables + External Secrets).

- **FR-004**: System MUST support two ingress patterns: Internal Only (ClusterIP service, internal DNS name) and External via Tunnel (ClusterIP service, public DNS name, Cloudflare Ingress).

- **FR-004a**: System MUST implement conditional auto-merge for pull requests: automatically merge if all basic validation gates pass (schema validation, kustomization build, no drift), but flag high-risk changes (external ingress, new external DNS entries) for human post-deployment review via issue or comment on merged PR.

- **FR-005**: System MUST validate generated manifests against Kubernetes OpenAPI schema before committing to Git.

- **FR-006**: System MUST generate proper namespace structure and respect existing kustomization patterns in the repository.

- **FR-007**: System MUST create a feature branch with descriptive name (e.g., `feat/app/<app-name>`) and commit generated manifests with conventional commit message.

- **FR-008**: System MUST create a pull request linking the feature branch to main, describing changes and validation status.

- **FR-009**: System MUST support two backup strategy options for Kubernetes/GitOps deployments: None, and Volsync Snapshots (daily). TrueNAS/Komodo backup is handled by separate restic implementations maintained by their respective systems and is not in scope for Backstage templates.

- **FR-010**: System MUST provide a separate "Deploy NAS App" template that creates Komodo-compatible deployment requests.

- **FR-011**: System MUST enforce constitutional DNS intent: internal apps use `*.internal.hypyr.space`, external apps use `*.hypyr.space`.

- **FR-012**: System MUST log all template submissions with app name, operator identity, storage/ingress/backup choices for audit trail.

- **FR-013**: System MUST validate that requested container image exists (or provide best-effort validation) before generating manifests.

- **FR-014**: System MUST support custom namespace selection or provide sensible defaults (e.g., app-name namespace, `kube-system` for system components).

### Key Entities

- **App Request**: Represents a single app deployment request. Attributes: app-name, container-image, namespace, storage-pattern, ingress-pattern, backup-strategy, operator-id, timestamp.
  
- **Storage Pattern**: Pre-defined storage configuration template. Options: ephemeral, longhorn-persistent, nas-mount, s3-external. Each has specific YAML template fragments.

- **Ingress Pattern**: Pre-defined network exposure configuration. Options: internal-only, external-via-tunnel. Each has Service, Ingress, and ExternalDNS template fragments.

- **Backup Strategy**: Pre-defined backup configuration. Options: none, volsync-snapshots, s3-backup. Each has ReplicationDestination/ReplicationSource template fragments and credential requirements.

- **Komodo Request**: Represents a NAS app deployment request. Attributes: app-name, configuration, storage-location, operator-id, timestamp.

## Assumptions

1. **Authentik Integration Available**: The homelab already has Authentik configured as the identity provider. Backstage will authenticate users via existing Authentik instance.

2. **Git Repository Access**: Backstage will have Git credentials (via SSH key or PAT) to create branches, commit manifests, and create pull requests.

3. **Container Image Accessibility**: Container images referenced are publicly available (or private registry credentials are available to Backstage). No offline/air-gapped scenarios.

4. **Longhorn Already Deployed**: Longhorn storage backend is already installed and functional. Backstage only generates PVC requests.

5. **NFS Already Configured**: NAS NFS endpoint is pre-configured and accessible from cluster. Backstage generates mount points to existing endpoint.

6. **Komodo Already Deployed**: Komodo is installed and configured for NAS orchestration. Backstage can submit deployment requests via API.

7. **Flux Reconciliation Automatic**: After manifests are merged to main, Flux will automatically reconcile within ~30 seconds.

8. **No Breaking Existing Workflow**: Operators can still manually edit manifests, create pull requests, and deploy via Flux independently of Backstage.

9. **Repository Structure Stable**: The directory structure (`kubernetes/clusters/`, namespace patterns, kustomization layout) remains stable.

10. **DNS Already Configured**: Internal (`*.internal.hypyr.space`) and external (`*.hypyr.space`) DNS zones are configured. Backstage generates names matching these patterns.

## Success Criteria

1. **Deployment Velocity**: Operators can deploy a new app from Backstage template to running pod in under 5 minutes (form submission + auto-merge + Flux reconciliation).

2. **Configuration Accuracy**: 100% of generated manifests pass CI validation gates (schema, kustomization build, drift checks). No manual remediation needed post-generation.

3. **User Adoption**: At least 3 new apps deployed via Backstage within first month of deployment.

4. **Template Reusability**: Storage, Ingress, and Backup patterns are reused across multiple app deployments without modification.

5. **Audit Trail Completeness**: Every app deployment creates an audit log entry with operator identity, timestamp, and configuration choices.

6. **Error Handling**: Invalid inputs (missing required fields, invalid image names, credential failures) provide clear error messages before Git operations occur.

7. **DNS Compliance**: 100% of deployed apps use correct DNS naming pattern (internal vs. external) matching constitutional intent.

8. **Documentation**: Setup guide, template customization guide, and troubleshooting runbook are available and link from Backstage catalog.

---

## Clarifications Resolved

**Q1 - NAS Mount Endpoint Configuration**: Hybrid approach selected. Backstage provides dropdown of pre-configured NAS endpoints (from configuration); operator selects endpoint and specifies subpath. This balances convenience with flexibility.

**Q2 - Pull Request Merge Strategy**: Conditional auto-merge selected. PRs automatically merge if all basic validation gates pass (schema, kustomization build, no drift checks). High-risk changes (external ingress, new DNS entries) are flagged for human review via post-merge issue/comment.

**Q3 - Backup Strategy**: Custom approach. Kubernetes/GitOps deployments use Volsync Snapshots only. TrueNAS and Komodo maintain their own separate restic implementations outside Backstage's scope. This avoids duplication and respects each system's native backup capabilities.
