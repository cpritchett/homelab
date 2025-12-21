# PII & Secrets Controls
**TL;DR:** Use the git hook + gitleaks. PR check name to require: `pii_secrets_gate`.

## Changelog
- 2025-12-21: Replaced legacy secret-scanning workflow with `security-pii-secrets.yml` (gitleaks-only diff/full/fixtures); added local hooks + mise tasks.
- 2025-12-21: Initial discovery and policy drafting.

## Discovery & Context (2025-12-21)
- **Tooling:** `gitleaks` (8.30.0) pinned in `.mise.toml`; no other secret scanners via mise.
- **Tasks:** `Taskfile.yml` lacks secret/PII tasks; now covered via mise tasks.
- **Local guardrails (then):** No committed git hooks/installer; feedback only in CI.
- **CI (then):** `secret-scanning.yml` ran Gitleaks (action v2) + TruffleHog (v3.82.0) on PR/push; no scheduled scans; job names `gitleaks` and `trufflehog`.
- **Governance docs:** `docs/governance/ci-gates.md` documents secret scanning as Gate 4; `scripts/run-all-gates.sh` calls `gitleaks detect --source . --verbose`.
- **Configuration:** No repo-level `.gitleaks.toml`; relied on defaults; no allowlist.
- **Ignore coverage:** `.gitignore` had many secrets but missed kubeconfigs, backups/dumps, values*.yaml, *.tfplan, etc.
- **Gaps/Risks:** No staged scan hook; untuned rules; CI full-scan only; no periodic sweep; no fixtures; missing ignores; noisy TruffleHog.

## Policy & Controls (current)
### Scope
All contributors must prevent committing secrets, credentials, private keys, kubeconfigs, and any PII.

### Forbidden to Commit
- Private keys/certs (PEM/PKCS12/CRT/KEY/PFX)
- Kubeconfigs, client key/cert data
- Cloud/API tokens (AWS, GitHub, Cloudflare, etc.)
- Database creds/connection strings
- Environment files with secrets (`.env`, `*.env.*`)
- Terraform/Terragrunt secrets (`*.tfvars`, `*.tfplan`, state files)
- Backup/dump artifacts (`*.sql`, `*.dump`, `*.bak`, archives containing data)

### Safe Test Data
- Use synthetic, clearly fake values; label fixtures: `SYNTHETIC TEST FIXTURE — NOT A REAL SECRET`.
- Never reuse production values (even modified).

### If a Leak Occurs
1) Rotate immediately (assume compromise).
2) Remove from git (rewrite history if needed).
3) Add file pattern to `.gitignore` if it should never be committed.
4) Document remediation in PR/issue; add incident notes if sensitive.

### Allowlist Policy
- Use `.gitleaks.allowlist` for narrow path regexes with inline justification comments.
- Do not allowlist real secrets; only false positives or synthetic fixtures.

### Developer Workflow
- Install tools: `mise install`.
- Install hooks (once): `mise run hooks:install`.
- Staged scan: `mise run security:scan:staged` (same as pre-commit hook).
- Full repo scan: `mise run security:scan:repo`.
- Fixture test: `mise run security:test`.
- Allowlist: edit `.gitleaks.allowlist` with justification comment; rerun staged scan.

### CI Enforcement
- Workflow: `.github/workflows/security-pii-secrets.yml`.
- Required PR check: `pii_secrets_gate` (diff-focused gitleaks).
- Scheduled job: `pii_secrets_full` (weekly full scan).
- Fixture job: `pii_secrets_test` (ensures detectors stay effective).

### Configuration
- Gitleaks config: `.gitleaks.toml` (extends pinned upstream defaults + kubeconfig client-key rule).
- Allowlist file: `.gitleaks.allowlist` (paths only, with comments).
- Fixtures: `tests/security/fixtures/` (fake PEM, AWS key, GitHub token, kubeconfig); safe sample in `tests/security/safe/`.
- Git hook: `.githooks/pre-commit` (uses `gitleaks protect --staged`).

### References
- Governance gate: `docs/governance/ci-gates.md` (Gate 4: secret scanning)
- Tool pinning: `.mise.toml`
- README security summary: `README.md#security-guardrails`
