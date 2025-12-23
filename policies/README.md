# Kyverno Policies – Enforcement Sets

ClusterPolicies applied by `kubernetes/policies` are grouped by domain. Use PolicyExceptions sparingly and record approvals per ADR-0014.

## Required base set
- Storage: deny DB on Longhorn, restrict RWX, enforce Longhorn replicas, deny node-local for critical data, limit volume size, require VolSync for annotated PVCs.
- Secrets: deny inline secrets, require ExternalSecrets operator & allowed SecretStore.
- Ingress/Service safety: deny LoadBalancer external IPs, deny NodePort.
- Observability: Kyverno webhook/violation alerts.

## PolicyExceptions
- Namespace: `policy-exceptions`.
- Grant a single policy per exception; annotate with approver and justification.
