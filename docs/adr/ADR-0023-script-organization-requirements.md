# ADR-0023: Script Organization Requirements

**Status:** Accepted  
**Date:** 2025-01-17  
**Author:** Kiro AI Assistant

## Context

The repository contains various types of scripts serving different purposes:
1. **CI/validation scripts** - Ongoing use for gates and validation
2. **One-shot operational scripts** - Temporary scripts for specific tasks (migrations, cleanups, fixes)
3. **Infrastructure scripts** - Deployment and maintenance automation

Currently, all scripts are mixed together in `scripts/`, making it difficult to:
- Distinguish between ongoing vs temporary scripts
- Track the purpose and lifecycle of one-shot scripts
- Maintain script hygiene over time
- Understand which scripts are safe to remove after use

One-shot scripts tend to accumulate without clear organization, leading to:
- Uncertainty about which scripts are still needed
- Difficulty understanding script purpose and context
- Risk of running outdated or inappropriate scripts
- Repository clutter with obsolete automation

## Decision

Establish clear script organization requirements:

### 1. Script Categories

**Ongoing Scripts** (`scripts/`):
- CI validation scripts (gates, checks)
- Reusable automation tools
- Infrastructure maintenance scripts
- Must be maintained and kept current

**One-Shot Scripts** (`scripts/one-shot/YYYY-MM-DD-purpose/`):
- Temporary scripts for specific tasks
- Migration scripts
- Cleanup scripts
- Emergency fixes
- Must be dated and single-purpose

### 2. Organization Rules

**Ongoing Scripts Location**: `scripts/`
- Examples: `run-all-gates.sh`, `check-kustomize-build.sh`
- Must be maintained for ongoing use
- Should be documented and stable

**One-Shot Scripts Location**: `scripts/one-shot/YYYY-MM-DD-purpose/`
- Date format: ISO 8601 (YYYY-MM-DD)
- Purpose: Brief descriptive name
- Examples:
  - `scripts/one-shot/2025-01-17-harbor-legacy-cleanup/`
  - `scripts/one-shot/2025-01-15-migrate-dns-config/`
  - `scripts/one-shot/2025-01-10-fix-broken-certificates/`

### 3. One-Shot Script Requirements

Each one-shot directory MUST contain:
- **Script file(s)** - The actual automation
- **README.md** - Purpose, context, usage instructions, and completion status
- **Date in directory name** - When the script was created
- **Single purpose** - One specific task or closely related set of tasks

### 4. Lifecycle Management

**One-Shot Scripts**:
- Created for specific tasks with clear completion criteria
- Marked as completed in README.md when task is done
- May be archived or removed after successful completion and reasonable retention period
- Should include rollback instructions if applicable

**Ongoing Scripts**:
- Maintained indefinitely
- Updated as requirements change
- Must pass CI validation
- Should be documented for team use

### 5. Documentation Requirements

**Ongoing Scripts** must include:
- **Comprehensive header comment** with purpose, usage, dependencies, maintainer
- **Entry in central `scripts/README.md`** for quick reference
- **Individual README.md** for complex scripts (>50 lines or multiple functions)

**One-Shot Scripts** must include:
- **README.md in directory** with context, usage, completion criteria
- **Inline comments** explaining non-obvious operations
- **Rollback instructions** if applicable

## Consequences

### Positive
- **Clear separation** between temporary and permanent automation
- **Improved discoverability** - easy to find scripts by purpose and date
- **Better lifecycle management** - clear completion criteria for one-shot scripts
- **Reduced clutter** - obsolete scripts can be safely removed
- **Historical context** - date and purpose preserved in directory structure
- **Team clarity** - obvious which scripts are safe to run vs archive

### Negative / Tradeoffs
- **Additional structure** - requires discipline to organize scripts properly
- **Migration effort** - existing scripts may need reorganization
- **Directory proliferation** - more directories in scripts/

### Mitigation
- Provide clear examples and templates
- Document the organization rules in governance
- Enforce via CI validation
- Regular cleanup of completed one-shot scripts

## Alternatives Considered

### 1. Single scripts/ directory with naming conventions
**Rejected:** Harder to enforce, less clear separation, difficult to manage lifecycle

### 2. Separate repositories for one-shot scripts
**Rejected:** Adds complexity, loses context, harder to discover

### 3. Archive directory instead of dated directories
**Rejected:** Loses temporal context, harder to understand when scripts were relevant

## References

- Repository structure: [requirements/workflow/repository-structure.md](../../requirements/workflow/repository-structure.md)
- Invariants: [contracts/invariants.md](../../contracts/invariants.md)
- Implementation: `scripts/` directory organization