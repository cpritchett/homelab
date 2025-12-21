# Workflow Checks

Validation checklist for git workflow compliance.

## Manual / CI Checks

### Branch compliance
- [ ] `main` branch is protected (requires PR)
- [ ] Feature branches follow naming convention: `<type>/<scope>/<description>`
- [ ] No direct commits to `main`

### Commit compliance
- [ ] All commits follow Conventional Commits format
- [ ] All commits include scope (e.g., `feat(dns):`, `fix(ingress):`)
- [ ] Commit subjects are imperative mood, lowercase
- [ ] No trailing periods in commit subjects

### Pull request compliance
- [ ] PR title follows conventional commit format
- [ ] PR template checklist completed
- [ ] PR labeled appropriately (auto or manual)
- [ ] CI checks pass before merge
- [ ] Required reviews obtained

### Label compliance
- [ ] Auto-labeling configured via `.github/labeler.yml`
- [ ] Labels applied to all PRs
- [ ] Issues labeled appropriately
- [ ] Breaking changes labeled with `breaking`

### CI enforcement (optional)
- [ ] commitlint validates commit messages
- [ ] PR title linter validates PR titles
- [ ] Label validation in CI
