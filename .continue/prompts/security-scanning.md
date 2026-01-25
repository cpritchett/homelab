---
name: Security Scanning
description: Detect secrets and security issues before committing
invokable: true
---

Before finalizing changes, run security scanning:

```bash
gitleaks detect --source . --verbose --config .gitleaks.toml
```

**What it checks:**
- API keys and tokens
- Private keys
- Database credentials
- Hardcoded secrets

**Commit hooks also run:**
```bash
gitleaks protect --staged --redact
```

**If secrets are found:**
1. Remove the secret from the file
2. Invalidate the exposed credential (rotate keys, change passwords)
3. Commit the fix
4. Verify gitleaks passes
5. Note in PR description what was remediated

See `.gitleaks.toml` for configuration details.
