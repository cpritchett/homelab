# ADR-0008: Developer Tooling Stack

## Status
Accepted

## Context
Homelab repository requires task automation, dependency management, and supply chain security. Standardized tooling improves consistency and reduces friction for both humans and AI agents.

## Decision

### Task runner: Task (task.dev)
- **Use:** [Task](https://taskfile.dev) as Makefile replacement
- **Why:** YAML-based, cross-platform, clearer dependency management
- **Location:** `Taskfile.yml` at repo root
- **Scope:** Common operations (bootstrap, validate, deploy, test)

### Tooling/package management
- **mise:** Version management for tools (kubectl, talosctl, flux, etc.)
- **bun:** Fast JavaScript/TypeScript runtime and package manager (where JS/TS needed)
- **Location:** `.mise.toml` and `package.json` as appropriate

### Supply chain security
- **Socket.dev:** Free tier for dependency scanning
- **Scope:** Monitor npm/bun packages for security issues
- **Integration:** CI checks via Socket.dev GitHub App or CLI

## Consequences

**Benefits:**
- Task provides declarative automation with better UX than Make
- mise handles tool version pinning (no "works on my machine")
- bun offers fast installs and modern JS tooling
- Socket.dev provides free supply chain visibility

**Constraints:**
- Developers must install Task, mise, (optionally bun)
- Socket.dev free tier has rate limits
- Task syntax differs from Make (migration effort for existing scripts)

**Bootstrap requirements:**
```bash
# Install Task
brew install go-task/tap/go-task

# Install mise
curl https://mise.run | sh

# Install bun (optional)
curl -fsSL https://bun.sh/install | bash
```

## Alternatives considered

- **Make:** Standard but platform-specific quirks, harder to read
- **Just:** Similar to Task but less mature ecosystem
- **npm scripts:** Limited composability, no native dependency graphs
- **Snyk/Dependabot:** Socket.dev chosen for free tier + npm focus

## Links
- [Task documentation](https://taskfile.dev)
- [mise documentation](https://mise.jdx.dev)
- [bun documentation](https://bun.sh)
- [Socket.dev](https://socket.dev)
