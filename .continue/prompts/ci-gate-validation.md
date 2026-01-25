---
name: CI Gate Validation
description: Check if changes will pass all CI gates before completing work
invokable: true
---

Before completing any change, validate against the CI gates:

```bash
./scripts/run-all-gates.sh "PR title with ADR reference" "PR description"
```

**Key Gates (ALL must pass):**
- `no-invariant-drift.sh` — Prevents hardcoded invariants
- `require-adr-on-canonical-changes.sh` — Requires ADRs for governance changes
- `adr-must-be-linked-from-spec.sh` — Links ADRs from specs
- `gitleaks` / security scanning — Detects secrets

**Review validation output and include evidence in PR description.**

See `scripts/run-all-gates.sh` for details.
