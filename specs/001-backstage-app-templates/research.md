# Research: Backstage App Templating Platform

**Phase**: 0 (Research & Dependencies)  
**Date**: 2026-01-25  
**Status**: Complete  
**Purpose**: Resolve technical unknowns about Backstage scaffolder plugins, Git automation, and manifest templating

---

## 1. Backstage Scaffolder Architecture

**Question**: How do we create custom templates? What are hook capabilities?

**Decision**: Use Backstage Scaffolder with custom Node.js action hooks

**Rationale**: 
- Scaffolder is Backstage's native templating system (purpose-built for this use case)
- Supports custom actions via TypeScript/Node.js plugins
- Has rich form schema support (JSON Schema)
- Integrates with Backstage catalog for discovery
- Hooks can shell out to external scripts or use Node.js libraries

**How It Works**:
1. Create `template.yaml` with Backstage form schema (input)
2. Define `skeleton/` directory with placeholder YAML files
3. Create custom actions (TypeScript) or bash hooks to:
   - Render templates with user input
   - Validate manifests
   - Create Git branch and commit
   - Open pull request
   - Optionally merge (conditional auto-merge)
4. Template appears in Backstage catalog; operators click "Create"

**Implementation Approach**:
- Use Backstage's built-in actions for Git operations (`publish:github`, etc.)
- Write custom action for manifest templating (Handlebars or Nunjucks)
- Write custom action for Kubernetes schema validation
- Write custom action for Komodo API calls

**Example File**: See scaffolder docs at https://backstage.io/docs/features/software-catalog/software-templates/creating-templates

---

## 2. Git Automation Library

**Question**: How do we create branches, commit, and open PRs programmatically?

**Decision**: Use Octokit (GitHub's official Node.js SDK) for API calls; Git CLI for local operations

**Rationale**:
- Octokit is official, well-maintained, handles rate limiting gracefully
- Git CLI is already available in container; simple to invoke
- Hybrid approach: use Git CLI for local work, Octokit for remote operations (PR, auto-merge)
- Avoids complex git library dependencies (nodegit has C++ bindings, can be problematic in containers)

**Approach**:
```typescript
// In custom Backstage action:
import { Octokit } from "@octokit/rest";

const octokit = new Octokit({ auth: process.env.GITHUB_TOKEN });

// Create branch
await octokit.git.createRef({
  owner, repo,
  ref: `refs/heads/feat/app/${appName}`,
  sha: mainBranchSha
});

// Commit via local git CLI (manifests already written to disk)
// SECURITY: Use execFile to prevent shell injection
const { execFile } = require('child_process');
const { promisify } = require('util');
const execFileAsync = promisify(execFile);

await execFileAsync('git', ['add', 'kubernetes/clusters/...']);
await execFileAsync('git', ['commit', '-m', `feat(app): add ${appName}`]);

// Create PR via Octokit
const { data: pr } = await octokit.pulls.create({
  owner, repo,
  head: `feat/app/${appName}`,
  base: 'main',
  title: `feat: deploy ${appName}`,
  body: `...`
});

// Auto-merge (conditional)
if (allGatesPassed) {
  await octokit.pulls.merge({
    owner, repo,
    pull_number: pr.number,
    merge_method: 'squash'
  });
}
```

**Rate Limiting**: Octokit handles retries automatically with exponential backoff (default: 5 retries)

---

## 3. YAML Templating Engine

**Question**: How do we generate Kubernetes manifests from user input?

**Decision**: Use Handlebars with custom helpers

**Rationale**:
- Lightweight (no heavy dependencies)
- Simple syntax (familiar to operators)
- Rich custom helper support (we can add DNS validation helpers)
- Performance: <1ms per template render
- Can pre-compile templates for faster rendering on repeated calls

**Alternative Considered**: 
- Nunjucks (similar, but slightly heavier)
- Helm templating (overkill; would require Helm binary in container)
- Custom logic (error-prone; hard to maintain)

**Template Structure**:
```text
templates/storage/longhorn.yaml.hbs:
---
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
```

**Form Integration**:
- User selects storage pattern in form → Handlebars context includes `storage: "longhorn"`
- Conditional sections: `{{#if storage.includes "longhorn"}}...{{/if}}`
- Custom helpers: `DNS validation`, `storage size validation`

---

## 4. Kubernetes Manifest Validation

**Question**: How do we validate generated manifests before Git operations?

**Decision**: Use `kubernetes-models` library + custom OpenAPI schema validation

**Rationale**:
- `kubernetes-models` provides TypeScript types and schema validation
- Allows synchronous validation (user sees errors immediately, before Git operations)
- Lightweight (no external services required)
- Can reject manifests client-side before they hit the cluster

**Approach**:
```typescript
import { Deployment, Service, Ingress } from 'kubernetes-models/v1';

const manifest = YAML.parse(generatedYAML);

try {
  // Validate Deployment
  new Deployment({
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    ...manifest.deployment
  });
  
  // Validate Service
  new Service({
    apiVersion: 'v1',
    kind: 'Service',
    ...manifest.service
  });
  
  // Custom DNS intent validation
  const ingressHost = manifest.ingress.spec.rules[0].host;
  if (manifest.ingressPattern === 'external' && !ingressHost.endsWith('.hypyr.space')) {
    throw new Error('External apps must use *.hypyr.space DNS');
  }
  
  if (manifest.ingressPattern === 'internal' && !ingressHost.endsWith('.internal.hypyr.space')) {
    throw new Error('Internal apps must use *.internal.hypyr.space DNS');
  }
  
} catch (error) {
  // Return error to form; user sees validation error before Git
  throw new Error(`Manifest validation failed: ${error.message}`);
}
```

---

## 5. Authentik OIDC Integration

**Question**: How do we authenticate with existing Authentik instance?

**Decision**: Backstage OIDC plugin + Authentik configuration

**Rationale**:
- Backstage has official OIDC provider support
- Authentik supports standard OpenID Connect
- Zero additional auth infrastructure needed

**Configuration**:
```yaml
# app-config.yaml
auth:
  providers:
    oidc:
      production:
        metadataUrl: https://auth.internal.hypyr.space/application/o/backstage/.well-known/openid-configuration
        clientId: ${AUTHENTIK_CLIENT_ID}
        clientSecret: ${AUTHENTIK_CLIENT_SECRET}
        scope: openid profile email
```

**Deployment**:
- Create OIDC application in Authentik UI
- Store client ID + secret in Kubernetes Secret
- Mount in Backstage pod as env vars
- Users authenticate via Authentik Okta-compatible login

---

## 6. Conditional Auto-Merge Implementation

**Question**: How do we implement conditional auto-merge (auto if gates pass, flag high-risk)?

**Decision**: GitHub branch protection rules + GitHub Actions workflow

**Rationale**:
- Branch protection rules enforce required status checks
- GitHub Actions can add comments/labels for manual review
- No custom queue/state management needed
- Integrates with existing CI/CD

**Implementation**:

1. **Auto-merge prerequisite**:
   - All required checks pass (schema, kustomization, drift checks)
   - Use Octokit to auto-merge: `pull.merge({ merge_method: 'squash' })`

2. **High-risk flagging**:
   - Custom GitHub Actions workflow runs after PR creation
   - Detects high-risk changes (external ingress, new DNS, credentials)
   - Adds issue comment: "⚠️ Review required for high-risk changes"
   - Blocks auto-merge if high-risk detected (remove `auto-merge` label)

3. **High-Risk Criteria**:
   - Any external ingress (domain not internal.hypyr.space)
   - New `ExternalDNS` annotation
   - New Secret references (S3 credentials, etc.)
   - Changes to management namespace

**Example Workflow**:
```yaml
name: Flag High-Risk Merges
on: [pull_request]
jobs:
  check-high-risk:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Detect high-risk changes
        id: analyze
        run: |
          # Check if PR contains external ingress
          if grep -r "hypyr.space\|external-dns\|secret" kubernetes/; then
            echo "risk=high" >> $GITHUB_OUTPUT
          fi
      - name: Comment if high-risk
        if: steps.analyze.outputs.risk == 'high'
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '⚠️ **High-risk changes detected**\nPlease review before merge:\n- External ingress\n- DNS changes\n- Credentials\n\nManual approval required.'
            });
```

---

## 7. Technology Stack Summary

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **Templating Framework** | Backstage Scaffolder | Official, extensible, rich form support |
| **Form Input** | JSON Schema (Backstage standard) | Well-documented, validation built-in |
| **Manifest Generation** | Handlebars templates | Lightweight, fast, custom helpers |
| **Kubernetes Validation** | kubernetes-models + custom rules | Synchronous, offline-capable |
| **Git Operations** | Octokit + Git CLI | Official SDK, no C++ bindings |
| **Auth** | OIDC (Authentik) | Existing infrastructure, standard protocol |
| **Auto-Merge** | Octokit + GitHub Actions | No custom state, integrates with CI/CD |
| **Storage** | Backstage default (PostgreSQL) | Persistence not critical (Git is source of truth) |

---

## 8. Deployment Considerations

**Backstage Installation Method**: Helm chart
- Already packaged with all dependencies
- Simplifies updates and rollbacks
- Standard Kubernetes approach aligns with homelab architecture

**Container Image**: `ghcr.io/backstage/backend:latest` (official)
- Lightweight (~500MB)
- Regular security updates
- Supports Node.js 18+ environment

**Resource Footprint**:
- CPU: 100m requests, 500m limits
- Memory: 256Mi requests, 512Mi limits
- Storage: 1Gi for database (if PostgreSQL included)

---

## Conclusion

All research questions have been resolved. Technology choices are aligned with homelab principles:
- ✅ **Simplicity**: Backstage is purpose-built for this (no custom frameworks)
- ✅ **Safety**: Manifest validation happens before Git operations
- ✅ **DNS Intent**: Custom validation enforces constitutional rules
- ✅ **Identity-Gated**: Authentik OIDC integration existing
- ✅ **GitOps**: All state in Git; Backstage is UI only

**Next Step**: Proceed to Phase 1 (Design) to create data-model.md, API contracts, and quickstart guide.
