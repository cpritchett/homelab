# Policy Testing Framework

This directory contains test manifests to verify Kyverno policies correctly catch prohibited patterns.

## Structure

```
test/policies/
├── storage/
│   ├── valid/          # Manifests that SHOULD pass policies
│   └── invalid/        # Manifests that SHOULD be blocked
├── ingress/
│   ├── valid/
│   └── invalid/
├── secrets/
│   ├── valid/
│   └── invalid/
└── README.md
```

## Running Tests

### All policies against test manifests
```bash
task test:policies
```

### Specific domain
```bash
# Test storage policies
kyverno apply policies/storage/*.yaml --resource test/policies/storage/invalid/*.yaml

# Test ingress policies
kyverno apply policies/ingress/*.yaml --resource test/policies/ingress/invalid/*.yaml
```

### Expected outcomes

**Valid manifests:** Should pass all policies without errors  
**Invalid manifests:** Should be DENIED by at least one policy

## Adding Test Cases

1. **Create manifest** in appropriate `valid/` or `invalid/` directory
2. **Name descriptively**: `invalid-postgres-on-longhorn.yaml`, `valid-app-with-longhorn.yaml`
3. **Add comment header** explaining what is being tested
4. **Run test** to verify policy catches the issue (for invalid) or allows (for valid)

## Test Case Template

```yaml
# Test case: <description>
# Expected: <PASS|FAIL>
# Policy: <policy-name.yaml>
# Reason: <why this should/shouldn't be allowed>
apiVersion: <kind>
kind: <Kind>
metadata:
  name: test-<scenario>
spec:
  # ... test manifest
```

## CI Integration

These test cases are used by `.github/workflows/policy-enforcement.yml` to verify policies work correctly before deployment to the cluster.
