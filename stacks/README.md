# NAS Deployment Stacks

This directory contains deployment manifests for containerized workloads running on NAS nodes (non-Kubernetes infrastructure).

## Purpose

NAS nodes in this homelab (TrueNAS, Synology DSM) run containerized services outside of the Kubernetes cluster. These deployments use different orchestration mechanisms (Docker Compose, systemd units, etc.) and should not be confused with Kubernetes workloads.

## Organization

Subdirectories are organized by NAS node hostname:
- `barbary/` - 45Drives HL15 (TrueNAS, primary storage)
- `razzia/` - Synology DS918+ (DSM, secondary NAS, backup target)

## Deployment Methods

Common deployment mechanisms for NAS stacks include:
- Docker Compose
- systemd service units
- Native NAS app configurations
- Container orchestration tools specific to the NAS platform

## Separation from Kubernetes

- **Kubernetes workloads** → `kubernetes/` directory (managed by Flux)
- **NAS workloads** → `stacks/` directory (this directory)
- **Infrastructure provisioning** → `infra/` directory

## References

- See: [ADR-0020](../docs/adr/ADR-0020-bootstrap-storage-governance-codification.md) - Decision to create this directory
- See: [Repository Structure](../requirements/workflow/repository-structure.md) - Governance documentation
