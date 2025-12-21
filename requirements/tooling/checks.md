# Tooling Checks

Validation checklist for tooling compliance.

## Manual / CI Checks

### Task runner
- [ ] `Taskfile.yml` exists at repo root
- [ ] No `Makefile` introduced when Task can be used
- [ ] Common operations documented as Task targets
- [ ] Task targets follow naming conventions

### Version management
- [ ] `.mise.toml` exists at repo root
- [ ] All required tools pinned in `.mise.toml`
- [ ] No global tool installations without version pins
- [ ] Documentation references mise for tool installation
- [ ] `conftest` installed via mise (not brew/curl)
- [ ] `kyverno` CLI installed via mise (not brew/curl)

### Policy tooling
- [ ] Conftest used for non-Kubernetes policies (repository structure, IaC)
- [ ] Kyverno used for Kubernetes resource policies
- [ ] No ad-hoc bash validation scripts (use Conftest/Rego instead)
- [ ] Policy tools installed via mise, not inline in scripts
- [ ] CI workflows use `jdx/mise-action` for tool installation

### Supply chain security
- [ ] Socket.dev configured for dependency scanning
- [ ] npm/bun packages scanned before merging
- [ ] No new dependencies without security review
- [ ] Socket.dev GitHub App or CLI integrated in CI

### YAML templating (ytt)
- [ ] `talos/templates/schema.yaml` defines data values schema
- [ ] `talos/templates/base.yaml` is main template
- [ ] `talos/values/{node}.yaml` exists for each node
- [ ] `talos/render.sh` script available
- [ ] CI workflow `talos-templates.yml` runs on talos/ changes
- [ ] Rendered configs not committed (in `.gitignore`)

### Optional tooling
- [ ] If JS/TS present, bun is preferred over npm/yarn
- [ ] `package.json` uses lockfile (`bun.lockb` or `package-lock.json`)
