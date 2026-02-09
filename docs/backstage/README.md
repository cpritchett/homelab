# Backstage App Templating Platform

This directory contains the Backstage implementation for the homelab self-service app deployment platform.

## Status

**Phase 1 Complete**: Infrastructure & Backstage Deployment
- ✅ Kubernetes namespace and manifests created
- ✅ HelmRelease configured with app-template pattern
- ✅ ExternalSecret configured for GitHub and Authentik integration
- ✅ Ingress configured for internal DNS (backstage.in.hypyr.space)
- ✅ All CI gates pass

**Phase 2 In Progress**: GitOps App Template - Form Definition
- ✅ Template YAML created with complete form schema
- ✅ Handlebars templates created for all manifest types
- ⏳ Custom scaffolder actions need implementation (TypeScript)
- ⏳ Validation logic needs implementation
- ⏳ Git operations need implementation

## Directory Structure

```
backstage/
├── package.json                           # Node.js dependencies
├── scaffolder-templates/
│   ├── gitops-app-template/
│   │   ├── template.yaml                  # Backstage template definition
│   │   └── skeleton/                      # Handlebars templates
│   │       ├── deployment.yaml.hbs
│   │       ├── service.yaml.hbs
│   │       ├── ingress.yaml.hbs
│   │       ├── pvc-longhorn.yaml.hbs
│   │       ├── pvc-nfs.yaml.hbs
│   │       ├── volsync.yaml.hbs
│   │       └── kustomization.yaml.hbs
│   └── komodo-app-template/
│       ├── template.yaml                  # NAS deployment template
│       └── skeleton/
└── src/
    └── actions/                           # Custom scaffolder actions
        ├── generateManifests.ts           # TODO: Manifest generation logic
        ├── validateManifests.ts           # TODO: Schema validation
        ├── createGitBranch.ts             # TODO: Git branch creation
        ├── commitFiles.ts                 # TODO: Git commit
        └── conditionalMerge.ts            # TODO: Auto-merge logic
```

## Kubernetes Deployment

The Backstage application is deployed to the homelab cluster at:

```
kubernetes/clusters/homelab/apps/backstage/
├── namespace.yaml                         # backstage namespace
├── kustomization.yaml                     # Main kustomization
└── backstage/
    ├── kustomization.yaml
    └── app/
        ├── kustomization.yaml
        ├── helmrelease.yaml               # Flux HelmRelease
        ├── externalsecret.yaml            # 1Password integration
        └── pvc.yaml                       # PostgreSQL/data storage
```

## Prerequisites for Full Implementation

To complete the implementation, the following work is required:

### 1. Install Dependencies

```bash
cd backstage
npm install
```

### 2. Implement Custom Scaffolder Actions

Create TypeScript implementations in `src/actions/`:

- `generateManifests.ts`: Render Handlebars templates with form input
- `validateManifests.ts`: Validate against Kubernetes schemas and constitutional rules
- `createGitBranch.ts`: Create feature branch via Octokit
- `commitFiles.ts`: Commit generated manifests
- `conditionalMerge.ts`: Auto-merge if gates pass, flag if high-risk

### 3. Register Actions in Backstage Backend

Update Backstage backend configuration to register custom actions:

```typescript
// packages/backend/src/plugins/scaffolder.ts
import { generateManifestsAction } from '../../actions/generateManifests';
import { validateManifestsAction } from '../../actions/validateManifests';
// ... etc

const actions = [
  generateManifestsAction(),
  validateManifestsAction(),
  // ... etc
];
```

### 4. Configure 1Password Secrets

Create a 1Password item named `backstage` with the following fields:

- `GITHUB_TOKEN`: GitHub Personal Access Token with `repo` scope
- `AUTHENTIK_CLIENT_ID`: Authentik OIDC client ID
- `AUTHENTIK_CLIENT_SECRET`: Authentik OIDC client secret

### 5. Configure Authentik Application

1. Log into Authentik admin UI
2. Create new OIDC Provider:
   - Name: `backstage`
   - Client Type: `Confidential`
   - Redirect URIs: `https://backstage.in.hypyr.space/api/auth/oidc/handler/frame`
3. Create Application:
   - Name: `Backstage`
   - Slug: `backstage`
   - Provider: `backstage`
4. Note the Client ID and Client Secret and add to 1Password

### 6. Deploy to Cluster

```bash
# Commit the Kubernetes manifests
git add kubernetes/clusters/homelab/apps/backstage/
git commit -m "feat(backstage): add Backstage deployment"

# Push to trigger Flux reconciliation
git push

# Wait for deployment
kubectl -n backstage rollout status deployment/backstage

# Access Backstage
open https://backstage.in.hypyr.space
```

## Testing

### Test Template Rendering

```bash
cd backstage
npm run dev

# Navigate to http://localhost:3000/create
# Select "Deploy GitOps App" template
# Fill form and verify manifest generation
```

### Test Validation

```bash
# Run validation against generated manifests
kubectl kustomize <generated-manifests-dir>
kubectl apply --dry-run=client -f <generated-manifests-dir>
```

## Next Steps

1. **Complete Custom Actions**: Implement TypeScript actions in `src/actions/`
2. **Integration Testing**: Deploy test app via Backstage, verify it runs
3. **Documentation**: Create operator runbook in Backstage catalog
4. **Monitoring**: Add Prometheus metrics for template usage
5. **Komodo Template**: Implement NAS deployment workflow

## References

- [Backstage Scaffolder Documentation](https://backstage.io/docs/features/software-catalog/software-templates)
- [Custom Scaffolder Actions](https://backstage.io/docs/features/software-templates/writing-custom-actions)
- [Handlebars Templating](https://handlebarsjs.com/)
- [Feature Specification](../specs/001-backstage-app-templates/spec.md)
- [Implementation Plan](../specs/001-backstage-app-templates/plan.md)
