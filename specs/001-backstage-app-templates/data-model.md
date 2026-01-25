# Data Model: Backstage App Templating Platform

**Phase**: 1 (Design)  
**Date**: 2026-01-25  
**Status**: Complete  
**Purpose**: Define data schemas, entity relationships, and validation rules

---

## Overview

The Backstage App Templating system manages two primary workflows:

1. **GitOps App Workflow**: Form → Manifest Generation → Git Commit → PR → Merge → Flux Sync
2. **NAS App Workflow**: Form → Komodo Request → API Call → TrueNAS Deployment

Both workflows are driven by pre-defined patterns (storage, ingress, backup) that users select from dropdown menus.

---

## Primary Entities

### 1. App Request (GitOps Workflow)

**Purpose**: Represents a single app deployment request submitted via Backstage form

**Schema**:
```typescript
interface AppRequest {
  // Metadata
  id: string;                          // UUID; unique per request
  operatorId: string;                  // Authentik user ID
  timestamp: string;                   // ISO 8601 creation time
  status: 'pending' | 'success' | 'failed'; // Workflow status
  
  // Application Details
  appName: string;                     // Kubernetes-compatible name (lowercase, alphanumeric, hyphens)
  containerImage: string;              // e.g., ghcr.io/owner/app:v1.0.0
  containerImageValidated: boolean;    // Did validation pass? (registry check or pull attempt)
  
  // Kubernetes Configuration
  namespace: string;                   // Target namespace; defaults to appName if not specified
  resourceRequests?: {
    cpu?: string;                      // e.g., "100m"; validation rule: required for production
    memory?: string;                   // e.g., "256Mi"; validation rule: required for production
  };
  
  // Storage Pattern
  storagePattern: 'ephemeral' | 'longhorn-persistent' | 'nas-mount' | 's3-external';
  storageConfig: {
    // For longhorn-persistent:
    sizeGi?: number;                   // PVC size in Gigabytes; validation: 1-1000
    
    // For nas-mount:
    nasEndpoint?: string;              // Selected from dropdown; e.g., "nfs://nas.internal:2049"
    nasSubpath?: string;               // e.g., "/mnt/apps/myapp"; validation: must not contain ..
    
    // For s3-external:
    s3Bucket?: string;                 // Bucket name; validation: AWS-compatible name
    s3Region?: string;                 // e.g., "us-east-1"; validation: known AWS region
    s3UseExternalSecrets?: boolean;    // Use External Secrets operator? (if credentials available)
  };
  
  // Ingress Pattern
  ingressPattern: 'internal-only' | 'external-via-tunnel';
  ingressConfig: {
    // For internal-only:
    internalHostname?: string;         // Auto-generated: appName.internal.hypyr.space
    
    // For external-via-tunnel:
    externalHostname?: string;         // Auto-generated: appName.hypyr.space
    cloudflareZoneId?: string;         // Pre-configured; used by ExternalDNS
  };
  
  // Backup Strategy
  backupStrategy: 'none' | 'volsync-snapshots';
  backupConfig?: {
    // For volsync-snapshots:
    retentionDays?: number;            // How long to keep snapshots; default: 30
    schedule?: string;                 // Cron schedule; default: "0 2 * * *" (2am daily)
  };
  
  // Git Workflow
  featureBranch?: string;              // Auto-generated: feat/app/appName-<hash>
  commitSha?: string;                  // Commit SHA of manifest commit
  prNumber?: number;                   // GitHub PR number
  prUrl?: string;                      // Link to PR
  mergedAt?: string;                   // Timestamp when merged
  
  // Validation Results
  validationErrors?: string[];         // Errors encountered during form submission
  manifestValidationErrors?: string[]; // Kubernetes schema validation errors (pre-commit)
}
```

**Validation Rules**:

| Field | Rule | Error Message |
|-------|------|---------------|
| `appName` | Matches `^[a-z0-9]([-a-z0-9]*[a-z0-9])?$` | "App name must be lowercase alphanumeric with hyphens" |
| `containerImage` | Must be pullable (or registry check passes) | "Container image not found. Verify image name and registry access" |
| `namespace` | If custom, must not be reserved (kube-*, backstage, etc.) | "Namespace is reserved. Choose a different namespace" |
| `storagePattern` + `ingressPattern` | No incompatible combinations | All combinations valid (see matrix below) |
| `ingressHostname` | Internal apps only use `*.internal.hypyr.space` | "Internal apps must use .internal.hypyr.space domain" |
| `ingressHostname` | External apps only use `*.hypyr.space` | "External apps must use .hypyr.space domain" |
| `nasSubpath` | Does not contain `..` | "Subpath must not contain relative directory references" |
| `s3UseExternalSecrets` | If true, S3 credentials must be available | "S3 credentials not configured in cluster" |

**Storage/Ingress Compatibility Matrix**:

| Storage Pattern | Internal-Only | External-Tunnel | Notes |
|-----------------|---------------|-----------------|-------|
| Ephemeral | ✅ | ✅ | No persistence; suitable for stateless apps |
| Longhorn | ✅ | ✅ | Standard persistent; all namespaces supported |
| NAS Mount | ✅ | ✅ | Shared storage; suitable for multi-read scenarios |
| S3 External | ✅ | ✅ | Cloud storage; suitable for backup/archive |

(All combinations valid; no restrictions)

---

### 2. Storage Pattern

**Purpose**: Pre-defined YAML template fragments for storage configuration

**Schema**:
```typescript
interface StoragePattern {
  id: string;                          // 'ephemeral', 'longhorn-persistent', 'nas-mount', 's3-external'
  name: string;                        // Display name: "Ephemeral", "Longhorn Persistent", etc.
  description: string;                 // User-friendly description
  template: string;                    // Handlebars YAML template fragment
  requiredFields: string[];            // Fields user must provide: ['sizeGi'] for Longhorn
  volumeName: string;                  // e.g., 'app-data'; used in Pod spec volumes
}
```

**Examples**:

#### Ephemeral
```yaml
# No PVC generated; inline volume
# Pod spec includes:
# volumes:
#   - name: app-data
#     emptyDir: {}
```

#### Longhorn Persistent
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{appName}}-data
  namespace: {{namespace}}
spec:
  storageClassName: longhorn
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: {{storageSize}}Gi
---
# Pod spec includes:
# volumes:
#   - name: app-data
#     persistentVolumeClaim:
#       claimName: {{appName}}-data
```

#### NAS Mount
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: {{appName}}-nfs-pv
spec:
  capacity:
    storage: 100Gi  # Estimated; not enforced
  accessModes:
    - ReadWriteMany
  nfs:
    server: {{nasEndpoint}}  # e.g., nas.internal
    path: {{nasSubpath}}     # e.g., /mnt/apps/myapp
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{appName}}-data
  namespace: {{namespace}}
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
  volumeName: {{appName}}-nfs-pv
---
# Pod spec includes:
# volumes:
#   - name: app-data
#     persistentVolumeClaim:
#       claimName: {{appName}}-data
```

#### S3 External
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{appName}}-s3-credentials
  namespace: {{namespace}}
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: "{{ s3AccessKey }}"
  AWS_SECRET_ACCESS_KEY: "{{ s3SecretKey }}"
---
# Pod spec includes environment variables:
# env:
#   - name: S3_BUCKET
#     value: {{s3Bucket}}
#   - name: S3_REGION
#     value: {{s3Region}}
#   - name: AWS_ACCESS_KEY_ID
#     valueFrom:
#       secretKeyRef:
#         name: {{appName}}-s3-credentials
#         key: AWS_ACCESS_KEY_ID
#   - name: AWS_SECRET_ACCESS_KEY
#     valueFrom:
#       secretKeyRef:
#         name: {{appName}}-s3-credentials
#         key: AWS_SECRET_ACCESS_KEY
```

---

### 3. Ingress Pattern

**Purpose**: Pre-defined network exposure configuration (Service, Ingress, ExternalDNS)

**Schema**:
```typescript
interface IngressPattern {
  id: string;                          // 'internal-only', 'external-via-tunnel'
  name: string;                        // Display name
  description: string;
  service: string;                     // Handlebars YAML template for Service
  ingress: string;                     // Handlebars YAML template for Ingress
  externaldns?: string;                // Optional ExternalDNS annotation
}
```

**Examples**:

#### Internal-Only
```yaml
# Service
apiVersion: v1
kind: Service
metadata:
  name: {{appName}}
  namespace: {{namespace}}
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 8080
      name: http
  selector:
    app: {{appName}}
---
# Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{appName}}
  namespace: {{namespace}}
spec:
  ingressClassName: nginx
  rules:
    - host: {{appName}}.internal.hypyr.space
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{appName}}
                port:
                  number: 80
```

#### External-via-Tunnel
```yaml
# Service (same as internal)
apiVersion: v1
kind: Service
metadata:
  name: {{appName}}
  namespace: {{namespace}}
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 8080
      name: http
  selector:
    app: {{appName}}
---
# Ingress (with Cloudflare annotations)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{appName}}
  namespace: {{namespace}}
  annotations:
    external-dns.alpha.kubernetes.io/hostname: {{appName}}.hypyr.space
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
spec:
  ingressClassName: nginx
  rules:
    - host: {{appName}}.hypyr.space
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{appName}}
                port:
                  number: 80
```

---

### 4. Backup Strategy

**Purpose**: Pre-defined backup configuration for Kubernetes-native apps

**Schema**:
```typescript
interface BackupStrategy {
  id: string;                          // 'none', 'volsync-snapshots'
  name: string;                        // Display name
  description: string;
  template?: string;                   // Handlebars YAML template for Volsync ReplicationDestination
  requiredFields?: string[];           // Fields user must provide (if any)
}
```

**Examples**:

#### None
```yaml
# No backup resources generated
```

#### Volsync Snapshots
```yaml
apiVersion: volsync.backube/v1alpha1
kind: ReplicationDestination
metadata:
  name: {{appName}}-backup
  namespace: {{namespace}}
spec:
  trigger:
    schedule: "{{backupSchedule}}"     # Default: "0 2 * * *"
  restic:
    pruneIntervalDays: {{retentionDays}} # Default: 30
    repository: {{volsyncRepository}}  # From cluster config: e.g., s3://backups/...
    copyMethod: Snapshot              # Use Kubernetes snapshots
    accessSecret:
      name: restic-credentials        # Pre-configured in cluster
    volumeSnapshotClassName: "{{volumeSnapshotClass}}" # From cluster config
  source:
    pvcName: {{appName}}-data         # Must match PVC from storage pattern
```

---

### 5. Komodo Request (NAS Workflow)

**Purpose**: Represents a TrueNAS app deployment request

**Schema**:
```typescript
interface KomodoRequest {
  // Metadata
  id: string;                          // UUID
  operatorId: string;                  // Authentik user ID
  timestamp: string;                   // ISO 8601
  status: 'pending' | 'success' | 'failed';
  
  // Application Details
  appName: string;                     // Kubernetes-compatible name
  appDescription?: string;             // Optional description
  
  // Komodo Configuration
  komodoRequest: {
    appName: string;
    appVersion: string;                // e.g., "latest"
    appConfig: {                        // App-specific configuration
      [key: string]: any;              // Free-form; depends on Komodo app manifest
    };
    storageLocation?: string;          // TrueNAS dataset path; e.g., "/mnt/pool/apps"
  };
  
  // Submission
  komodoApiUrl: string;                // Komodo webhook URL
  submissionStatus?: string;           // Response from Komodo
  errorMessage?: string;               // If failed
}
```

**Example Komodo Request Payload**:
```json
{
  "appName": "myapp",
  "appVersion": "1.0.0",
  "appConfig": {
    "storage": {
      "enabled": true,
      "size": "50Gi",
      "path": "/data"
    },
    "network": {
      "ports": [8080]
    }
  },
  "storageLocation": "/mnt/pool/apps/myapp"
}
```

---

## Entity Relationships

```
Backstage Form Submission
    ↓
AppRequest (GitOps) OR KomodoRequest (NAS)
    ↓
Validates against:
  ├── AppRequest schema + validation rules
  ├── StoragePattern compatibility
  ├── IngressPattern compatibility
  ├── BackupStrategy compatibility
  └── Constitutional rules (DNS names, etc.)
    ↓
Generate Manifests (GitOps) OR Komodo Payload (NAS)
    ↓
Validate Kubernetes schema (GitOps only)
    ↓
Create Git branch & commit (GitOps) OR Call Komodo API (NAS)
    ↓
Create PR (GitOps) OR Report status (NAS)
    ↓
Merge PR if gates pass (GitOps) OR Monitor Komodo dashboard (NAS)
    ↓
Flux reconciles (GitOps) OR Komodo deploys (NAS)
    ↓
AppRequest/KomodoRequest status updated to 'success' or 'failed'
```

---

## Validation Flow

### Client-Side Validation (Form)

1. **Required fields**: All marked fields must be filled
2. **App name**: Lowercase, alphanumeric, hyphens only
3. **Container image**: Format validation (can add registry check)
4. **Storage pattern**: Selected from dropdown (always valid)
5. **Storage config**: Depends on selected pattern
   - Longhorn: sizeGi must be 1-1000
   - NAS: subpath must not contain `..`
   - S3: bucket name must be AWS-compatible
6. **Ingress pattern**: Selected from dropdown (always valid)
7. **Ingress hostname**: Auto-generated based on pattern
8. **Backup strategy**: Selected from dropdown (always valid)

### Server-Side Validation (Before Git)

1. **Manifest schema**: Kubernetes objects must be valid
2. **Constitutional rules**: DNS names must match intent
3. **Storage pattern compatibility**: PVC/volume config must be coherent
4. **Image validation**: (Optional) Attempt to pull or query registry

### CI Validation (After Git)

Existing gates automatically validate:
- ✅ `check-kustomize-build.sh` - Kustomization must render
- ✅ `check-cross-env-refs.sh` - No cross-environment leakage
- ✅ `no-invariant-drift.sh` - No violations of invariants
- ✅ `check-no-plaintext-secrets.sh` - No hardcoded secrets

---

## State Transitions

### GitOps App Request

```
Form submitted
    ↓ (validate)
pending → manifest generation
    ↓ (validate schemas)
pending → git branch created + committed
    ↓
pending → PR created
    ↓ (auto-merge if gates pass)
success → merged + deployment via Flux
    
OR on error:
pending → failed (with error message)
```

### NAS App Request

```
Form submitted
    ↓ (validate)
pending → Komodo API call
    ↓
pending → Komodo processes
    ↓ (Komodo status polled)
success → deployed via Komodo
    
OR on error:
pending → failed (with Komodo error)
```

---

## Summary

The data model is centered around **pre-defined patterns** that operators select from dropdowns. This ensures:

1. **Safety**: No free-form configuration; operators can't create invalid manifests
2. **Consistency**: All apps follow same patterns (easy to maintain, upgrade)
3. **Compliance**: DNS intent enforcement built into template rules
4. **Auditability**: Every request logged with operator ID, timestamp, choices

Next: Create API contracts (scaffolder form schema, generator API) and quickstart guide.
