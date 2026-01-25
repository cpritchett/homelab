# Quick Start: Backstage App Templating Platform

**Phase**: 1 (Design)  
**Date**: 2026-01-25  
**Status**: Complete  
**Purpose**: Setup guide, template customization, deployment checklist

---

## Table of Contents

1. [Local Development Setup](#local-development-setup)
2. [Testing Scaffolder Templates](#testing-scaffolder-templates)
3. [Deployment to Cluster](#deployment-to-cluster)
4. [Customizing Templates](#customizing-templates)
5. [Troubleshooting](#troubleshooting)

---

## Local Development Setup

### Prerequisites

- Node.js 18+ (verify: `node --version`)
- Git (verify: `git --version`)
- Docker (for local Backstage container)
- kubectl (for cluster testing)
- Backstage CLI (install: `npm install -g @backstage/cli`)

### Step 1: Clone Repository & Create Development Branch

```bash
cd /Users/cpritchett/src/personal/homelab
git checkout 001-backstage-app-templates

# Create dev branch for template work
git checkout -b feat/scaffolder-templates
```

### Step 2: Create Backstage Project (if not already in repo)

```bash
# Option A: Add Backstage to existing monorepo (RECOMMENDED for homelab)
npx @backstage/create-app@latest \
  --templateName monorepo \
  --path backstage

# Option B: Start standalone (simpler for initial development)
npx @backstage/create-app@latest \
  --path backstage-local

cd backstage
```

### Step 3: Install Dependencies

```bash
# Install Backstage core + plugins
npm install

# Add Scaffolder plugin (if not already installed)
npm install @backstage/plugin-scaffolder-backend

# Add GitHub integration (for Git operations)
npm install @octokit/rest
npm install @backstage/integration

# Add Kubernetes models (for validation)
npm install kubernetes-models

# Add Handlebars (for templating)
npm install handlebars
```

### Step 4: Create Scaffolder Templates Directory

```bash
mkdir -p scaffolder-templates/gitops-app-template/skeleton
mkdir -p scaffolder-templates/komodo-app-template/skeleton

# Create template.yaml for GitOps workflow
cat > scaffolder-templates/gitops-app-template/template.yaml << 'EOF'
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: gitops-app-template
  title: Deploy GitOps App
  description: Deploy a containerized app to Kubernetes with Backstage
  tags:
    - kubernetes
    - gitops
    - deployment
spec:
  owner: platform-team
  type: service

  parameters:
    - title: Application Details
      required: [appName, containerImage]
      properties:
        appName:
          type: string
          title: App Name
          description: Kubernetes-compatible app name (lowercase, alphanumeric, hyphens)
          pattern: '^[a-z0-9]([-a-z0-9]*[a-z0-9])?$'
          
        containerImage:
          type: string
          title: Container Image
          description: Full image URL (e.g., ghcr.io/owner/app:v1.0.0)
          
        namespace:
          type: string
          title: Namespace
          description: Target Kubernetes namespace (defaults to app name)
          default: ""

    - title: Storage Configuration
      properties:
        storagePattern:
          type: string
          title: Storage Pattern
          description: How should app data be persisted?
          enum:
            - ephemeral
            - longhorn-persistent
            - nas-mount
            - s3-external
          default: ephemeral
          
        storageSize:
          type: string
          title: Storage Size (GB)
          description: Only for Longhorn/NAS; size in GB (1-1000)
          pattern: '^[0-9]{1,4}$'
          default: "10"
          
        nasEndpoint:
          type: string
          title: NAS Endpoint
          description: Select pre-configured NAS endpoint
          enum:
            - "nfs://nas.internal:2049"
            - "nfs://nas-backup.internal:2049"
          
        nasSubpath:
          type: string
          title: NAS Subpath
          description: Subpath on NAS (e.g., /mnt/apps/myapp)
          
        s3Bucket:
          type: string
          title: S3 Bucket
          description: S3 bucket name

    - title: Ingress & DNS Configuration
      properties:
        ingressPattern:
          type: string
          title: Ingress Pattern
          description: How should app be exposed?
          enum:
            - internal-only
            - external-via-tunnel
          default: internal-only
          
    - title: Backup Strategy
      properties:
        backupStrategy:
          type: string
          title: Backup Strategy
          description: How should app data be backed up?
          enum:
            - none
            - volsync-snapshots
          default: none

  steps:
    - id: fetch-base
      name: Fetch Base
      action: fetch:plain
      input:
        url: "https://github.com/cpritchett/homelab.git"
        targetPath: ./base

    - id: generate-manifests
      name: Generate Kubernetes Manifests
      action: custom:generate-manifests
      input:
        appName: ${{ parameters.appName }}
        containerImage: ${{ parameters.containerImage }}
        namespace: ${{ parameters.namespace || parameters.appName }}
        storagePattern: ${{ parameters.storagePattern }}
        ingressPattern: ${{ parameters.ingressPattern }}
        backupStrategy: ${{ parameters.backupStrategy }}

    - id: publish-github
      name: Publish to GitHub
      action: publish:github
      input:
        allowedHosts: ['github.com']
        description: "feat: deploy ${{ parameters.appName }}"
        repoUrl: 'github.com?owner=cpritchett&repo=homelab'
        defaultBranch: main
        branchName: "feat/app/${{ parameters.appName }}"

    - id: auto-merge
      name: Request Auto-Merge
      action: custom:conditional-merge
      input:
        prNumber: ${{ steps.publish-github.output.pullRequestNumber }}
        isHighRisk: false  # Actual logic in action
EOF

echo "✅ GitOps template created"
```

### Step 5: Configure Backstage (app-config.yaml)

```bash
# Update app-config.yaml with Authentik OIDC and GitHub integration
cat >> app-config.yaml << 'EOF'

# GitHub integration for Git operations
integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}

# Authentik OIDC for authentication
auth:
  providers:
    oidc:
      development:
        metadataUrl: https://auth.internal.hypyr.space/application/o/backstage/.well-known/openid-configuration
        clientId: ${AUTHENTIK_CLIENT_ID}
        clientSecret: ${AUTHENTIK_CLIENT_SECRET}
        scope: openid profile email

# Scaffolder configuration
scaffolder:
  actions:
    'custom:generate-manifests':
      id: custom:generate-manifests
      handler: generateManifestsAction
EOF
```

### Step 6: Run Local Backstage Instance

```bash
# Start Backstage backend
npm start

# In another terminal, start frontend (if needed)
cd packages/app
npm start

# Backstage should now be available at http://localhost:3000
```

---

## Testing Scaffolder Templates

### Test 1: Form Input Validation

1. Navigate to http://localhost:3000/create
2. Click "Deploy GitOps App" template
3. Try invalid inputs and verify form validation:
   - **App name**: Try "MyApp" (uppercase) → Should show error
   - **Container image**: Try "invalid-image" (no registry) → Should validate or warn
   - **Storage size**: Try "99999" → Should reject >1000

**Expected**: Form prevents submission until all fields are valid

### Test 2: Manifest Generation

1. Fill form with valid inputs:
   ```
   App Name: test-nginx
   Container Image: docker.io/library/nginx:latest
   Storage Pattern: ephemeral
   Ingress Pattern: internal-only
   Backup Strategy: none
   ```

2. Click "Create"

3. Check output:
   - Git branch should be created: `feat/app/test-nginx`
   - Manifests should be in: `kubernetes/clusters/<cluster>/namespaces/test-nginx/`
   - Files generated: `deployment.yaml`, `service.yaml`, `ingress.yaml`

**Expected**: Manifests are generated with correct DNS names (`test-nginx.internal.hypyr.space`)

### Test 3: Kubernetes Schema Validation

1. Run validation script (custom action):
   ```bash
   node scripts/validate-manifests.js \
     kubernetes/clusters/default/namespaces/test-nginx
   ```

**Expected**: Output shows manifest schema is valid

### Test 4: Storage Pattern Testing

Test each pattern separately:

```bash
# Test Longhorn pattern
# App form: storagePattern=longhorn-persistent, storageSize=20
# Expected: PVC generated with 20Gi size

# Test NAS Mount pattern
# App form: storagePattern=nas-mount, nasEndpoint=nfs://nas.internal:2049, nasSubpath=/mnt/apps/myapp
# Expected: PV + PVC generated with NFS configuration

# Test Ephemeral pattern
# App form: storagePattern=ephemeral
# Expected: No PVC; only emptyDir volume
```

### Test 5: Ingress Pattern Testing

```bash
# Test Internal-Only
# App form: ingressPattern=internal-only
# Expected: Service type ClusterIP, Ingress host = appname.internal.hypyr.space

# Test External-via-Tunnel
# App form: ingressPattern=external-via-tunnel
# Expected: Service type ClusterIP, Ingress host = appname.hypyr.space, ExternalDNS annotations added
```

---

## Deployment to Cluster

### Prerequisites

- Kubernetes cluster access (verify: `kubectl cluster-info`)
- Authentik instance running (verify: `curl -k https://auth.internal.hypyr.space`)
- GitHub token with repo write permissions
- Komodo API endpoint accessible (if NAS template needed)

### Step 1: Prepare Secrets

```bash
# Create namespace
kubectl create namespace backstage

# GitHub PAT token (with repo, write access)
kubectl -n backstage create secret generic github-token \
  --from-literal=token=$GITHUB_TOKEN

# Authentik OIDC credentials
kubectl -n backstage create secret generic authentik-oidc \
  --from-literal=clientId=$AUTHENTIK_CLIENT_ID \
  --from-literal=clientSecret=$AUTHENTIK_CLIENT_SECRET

# Git SSH key (for commit signing)
kubectl -n backstage create secret generic git-ssh-key \
  --from-file=id_rsa=$HOME/.ssh/id_rsa \
  --from-file=id_rsa.pub=$HOME/.ssh/id_rsa.pub
```

### Step 2: Create Kubernetes Manifests

Create `kubernetes/clusters/default/namespaces/backstage/backstage.yaml`:

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backstage
  namespace: backstage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backstage
  template:
    metadata:
      labels:
        app: backstage
    spec:
      containers:
        - name: backstage
          image: ghcr.io/backstage/backend:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 7007
              name: http
          env:
            - name: GITHUB_TOKEN
              valueFrom:
                secretKeyRef:
                  name: github-token
                  key: token
            - name: AUTHENTIK_CLIENT_ID
              valueFrom:
                secretKeyRef:
                  name: authentik-oidc
                  key: clientId
            - name: AUTHENTIK_CLIENT_SECRET
              valueFrom:
                secretKeyRef:
                  name: authentik-oidc
                  key: clientSecret
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          livenessProbe:
            httpGet:
              path: /health
              port: 7007
            initialDelaySeconds: 30
            periodSeconds: 10

---
apiVersion: v1
kind: Service
metadata:
  name: backstage
  namespace: backstage
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 7007
      name: http
  selector:
    app: backstage

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backstage
  namespace: backstage
  annotations:
    external-dns.alpha.kubernetes.io/hostname: backstage.internal.hypyr.space
spec:
  ingressClassName: nginx
  rules:
    - host: backstage.internal.hypyr.space
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backstage
                port:
                  number: 80
```

### Step 3: Deploy to Cluster

```bash
# Apply manifests
kubectl apply -f kubernetes/clusters/default/namespaces/backstage/

# Wait for deployment
kubectl -n backstage rollout status deployment/backstage

# Check logs
kubectl -n backstage logs -f deployment/backstage
```

### Step 4: Access Backstage

```bash
# Port forward (for testing)
kubectl -n backstage port-forward svc/backstage 7007:80

# Access at http://localhost:7007
# Login via Authentik
```

---

## Customizing Templates

### Adding a New Storage Pattern

1. Create template fragment:
   ```bash
   cat > scaffolder-templates/gitops-app-template/skeleton/storage-custom.yaml.hbs << 'EOF'
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: {{appName}}-data
     namespace: {{namespace}}
   spec:
     storageClassName: custom-storage
     # ... custom config
   EOF
   ```

2. Update template form schema:
   ```yaml
   storagePattern:
     enum:
       - ephemeral
       - longhorn-persistent
       - nas-mount
       - s3-external
       - custom-storage  # Add here
   ```

3. Update manifest generator logic to handle new pattern

4. Test with form submission

### Updating DNS Names

To change domain names (e.g., from `hypyr.space` to `example.com`):

1. Update in `data-model.md` constant values
2. Update template Ingress rules
3. Update constitutional DNS intent rules
4. Re-test all forms

---

## Troubleshooting

### Template Not Appearing in Backstage UI

```bash
# Check if template is registered in catalog
curl http://localhost:7007/api/catalog/entities?filter=kind=template

# If missing, restart Backstage and reload page
kubectl -n backstage rollout restart deployment/backstage
```

### Manifest Generation Fails

```bash
# Check Backstage logs for generation errors
kubectl -n backstage logs deployment/backstage | grep -i "generate"

# Validate template syntax
npm run scaffolder:validate
```

### Git Operations Fail (PR not created)

```bash
# Verify GitHub token
kubectl -n backstage get secret github-token -o jsonpath='{.data.token}' | base64 -d

# Test token permissions
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user/repos

# If missing scopes, regenerate token in GitHub UI
```

### DNS Names Not Resolving

```bash
# Verify Ingress created
kubectl -n test-app get ingress

# Check ExternalDNS logs
kubectl -n externaldns logs -f deployment/external-dns | grep test-app

# Verify Cloudflare zone has DNS records
curl -X GET "https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN"
```

---

## Next Steps

1. **Integration Testing**: Deploy test app via Backstage, verify it runs on cluster
2. **Performance Testing**: Submit 10+ concurrent requests, verify all succeed
3. **Documentation**: Create runbook for operators
4. **Template Expansion**: Add more storage/ingress/backup patterns

---

## Support & Questions

For issues or questions:
1. Check logs: `kubectl -n backstage logs -f deployment/backstage`
2. Review spec: [spec.md](spec.md)
3. Review data model: [data-model.md](data-model.md)
4. Open GitHub issue with `backstage` label
