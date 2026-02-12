# homelab Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-02-10

## Active Technologies
- POSIX shell (`#!/bin/sh`) for scripts; YAML for Docker Compose and configuration files + Docker Swarm (orchestration), Caddy + caddy-docker-proxy (ingress), Homepage (dashboard), AutoKuma 2.0.0 (monitoring bridge), Uptime Kuma (monitoring), Komodo (stack deployment), 1Password Connect (secrets), Authentik (SSO) (007-media-stack-migration)
- TrueNAS host paths — `/mnt/apps01/appdata/media/<service>/` (application config), `/mnt/data01/data` (media files); Docker overlay networks for service communication (007-media-stack-migration)

- POSIX shell (`#!/bin/sh`) for scripts; YAML for Docker Compose and configuration files + Docker Swarm (orchestration), Caddy + caddy-docker-proxy (ingress), Homepage (dashboard), AutoKuma 2.0.0 (monitoring bridge), Uptime Kuma (monitoring), Komodo (stack deployment), 1Password Connect (secrets) (002-label-driven-swarm-infrastructure)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for POSIX shell (`#!/bin/sh`) for scripts; YAML for Docker Compose and configuration files

## Code Style

POSIX shell (`#!/bin/sh`) for scripts; YAML for Docker Compose and configuration files: Follow standard conventions

## Recent Changes
- 007-media-stack-migration: Added POSIX shell (`#!/bin/sh`) for scripts; YAML for Docker Compose and configuration files + Docker Swarm (orchestration), Caddy + caddy-docker-proxy (ingress), Homepage (dashboard), AutoKuma 2.0.0 (monitoring bridge), Uptime Kuma (monitoring), Komodo (stack deployment), 1Password Connect (secrets), Authentik (SSO)

- 002-label-driven-swarm-infrastructure: Added POSIX shell (`#!/bin/sh`) for scripts; YAML for Docker Compose and configuration files + Docker Swarm (orchestration), Caddy + caddy-docker-proxy (ingress), Homepage (dashboard), AutoKuma 2.0.0 (monitoring bridge), Uptime Kuma (monitoring), Komodo (stack deployment), 1Password Connect (secrets)

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
