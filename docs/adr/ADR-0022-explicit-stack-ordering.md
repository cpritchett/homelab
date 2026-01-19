# ADR-0022: Explicit Stack Ordering with Order Fields

**Status:** SUPERSEDED - See implementation note below  
**Date:** 2025-01-17  
**Author:** Kiro AI Assistant

## Status Update (2025-01-18)

**This ADR describes a TOML-based format with explicit `order` fields that was never implemented.** 

The actual implementation uses a simpler colon-separated format in `stacks/registry.conf`:
```
# Format: stack_name:path:depends_on (comma-separated deps, empty for none)
proxy:00-proxy:
harbor:20-harbor:proxy
```

Ordering is achieved through dependency-based topological sorting only, without explicit order fields. This provides deterministic ordering while keeping the format simple and avoiding the complexity of TOML parsing.

---

## Context

The current stack deployment system uses `stacks/registry.conf` with dependency-based ordering via `depends_on` relationships. While this provides correct dependency resolution, it lacks explicit control over deployment sequence for stacks that don't have direct dependencies but should still deploy in a specific order.

The existing system relies solely on topological sorting of the dependency graph, which can result in non-deterministic ordering for independent stacks. This makes deployment behavior less predictable and harder to reason about, especially as the number of stacks grows.

For future-proofing and operational clarity, we need a system that supports:
1. Explicit numeric ordering for predictable deployment sequence
2. Dependency resolution to ensure constraints are respected
3. Stable, deterministic behavior regardless of stack addition order

## Decision

Add explicit `order` fields to all stack definitions in `stacks/registry.conf` and update the deployment logic to use a two-phase sorting approach:

1. **Primary sort:** By `order` field (lower numbers deploy earlier)
2. **Secondary sort:** Apply dependency resolution via topological sort

### Registry Format
```toml
[stacks.proxy]
path = "proxy"
depends_on = []
order = 10

[stacks.harbor]
path = "harbor"
depends_on = ["proxy"]
order = 20
```

### Deployment Logic
The `stacks/_bin/deploy-all` script will:
1. Sort stacks by `order` field first
2. Apply topological sorting to respect `depends_on` constraints
3. Deploy in the resulting order

### Ordering Conventions
- Use increments of 10 (10, 20, 30, etc.) to allow insertion of intermediate stacks
- Lower numbers deploy earlier
- `depends_on` relationships must still be honored even if `order` suggests different sequence

## Consequences

### Positive
- **Predictable ordering:** Deployment sequence is explicit and stable
- **Future-proof:** Easy to insert new stacks at specific points in the sequence
- **Backward compatible:** Existing `depends_on` logic is preserved and enhanced
- **Operational clarity:** Deployment order is immediately visible in the registry
- **Deterministic behavior:** Same ordering regardless of hash table iteration or file system order

### Negative / Tradeoffs
- **Additional maintenance:** Must assign `order` values when adding new stacks
- **Potential conflicts:** If `order` and `depends_on` suggest different sequences, dependency wins (which is correct but could be confusing)
- **Migration effort:** Existing stacks need `order` fields added

### Mitigation
- Use increment-of-10 convention to minimize conflicts
- Document that `depends_on` always takes precedence over `order`
- Update documentation to explain the dual-sorting approach

## Alternatives Considered

### 1. Directory name prefixes (e.g., `01-proxy`, `02-harbor`)
**Rejected:** Creates coupling between deployment order and filesystem layout. Makes refactoring harder and doesn't scale well.

### 2. Separate ordering file
**Rejected:** Splits related configuration across multiple files. The registry should be the single source of truth.

### 3. Pure dependency-based ordering
**Rejected:** Current approach. Works for direct dependencies but doesn't provide control over independent stack ordering.

### 4. Priority-based system with named priorities
**Rejected:** More complex than needed. Numeric ordering is simpler and more flexible.

## References

- Related specs: [repository structure](../../requirements/workflow/repository-structure.md)
- Related ADRs: [ADR-0021](./ADR-0021-stacks-registry-required.md)
- Implementation: `stacks/registry.conf`, `stacks/_bin/deploy-all`