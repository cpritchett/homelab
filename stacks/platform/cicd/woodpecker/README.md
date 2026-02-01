# Woodpecker CI/CD Stack

Self-contained Woodpecker CI/CD stack providing:
- Pipeline orchestration and execution
- Forgejo integration via OAuth2
- Docker-based pipeline execution
- Web UI with Caddy reverse proxy

## Quick Start

Per [ADR-0022](../../../../docs/adr/ADR-0022-truenas-komodo-stacks.md), stacks must be deployable through Komodo without external dependencies.

### Prerequisites

1. **External Docker network** (create once on host):
   ```bash
   docker network create proxy_network
   ```

2. **Host directories**:
   ```bash
   mkdir -p /mnt/apps01/appdata/woodpecker
   chown -R 1000:1000 /mnt/apps01/appdata/woodpecker
   chmod 755 /mnt/apps01/appdata/woodpecker
   ```

   Optional helper (run on TrueNAS): `stacks/scripts/set-host-permissions.sh`

3. **Forgejo OAuth2 Application** (one-time setup):
   - Log into Forgejo at `https://git.in.hypyr.space` as admin
   - Navigate to Settings > Applications > OAuth2 Applications
   - Create a new application:
     - Application Name: `Woodpecker CI`
     - Redirect URI: `https://ci.in.hypyr.space/authorize`
   - Copy the Client ID and Client Secret

4. **Configure environment** in Komodo:
   - Set `WOODPECKER_HOST`: `https://ci.in.hypyr.space`
   - Set `WOODPECKER_AGENT_SECRET`: (generate a random 32+ character string)
   - Set `WOODPECKER_GITEA_URL`: `https://git.in.hypyr.space`
   - Set `WOODPECKER_GITEA_CLIENT`: (from Forgejo OAuth2 app)
   - Set `WOODPECKER_GITEA_SECRET`: (from Forgejo OAuth2 app)
   - Set `WOODPECKER_ADMIN`: (username for initial admin user)
   - Set `CLOUDFLARE_API_TOKEN`: (for Caddy)

5. **Deploy via Komodo**:
   - Ensure Forgejo stack is running first
   - Add this stack directory in Komodo
   - Populate env/secret values
   - Deploy

## Usage

### Initial Setup

1. Access Woodpecker at `https://ci.in.hypyr.space`
2. Click "Login with Forgejo"
3. Authorize Woodpecker to access your Forgejo account
4. Enable pipelines on repositories

### Creating Pipelines

Create `.woodpecker.yml` in your Forgejo repository:

```yaml
steps:
  build:
    image: golang:1.23
    commands:
      - go build -o app .

  push:
    image: plugins/docker
    settings:
      registry: git.in.hypyr.space
      repo: git.in.hypyr.space/username/app
      tags: latest
    when:
      branch: main
```

### Container Registry Integration

Push images to Forgejo registry in pipelines:

```yaml
steps:
  push:
    image: plugins/docker
    settings:
      registry: git.in.hypyr.space
      repo: git.in.hypyr.space/username/myimage
      tags: latest
      username:
        from_secret: forgejo_username
      password:
        from_secret: forgejo_password
```

## Architecture Notes

- **Database**: SQLite (persistent storage at `/mnt/apps01/appdata/woodpecker/woodpecker.db`)
- **Agent**: Docker backend; pipelines execute as containers on the NAS host
- **Networking**: Connected to `proxy_network` for Caddy routing
- **Reverse proxy**: Caddy handles HTTPS termination
- **Authentication**: OAuth2 via Forgejo

### Security Considerations

⚠️ **Docker Socket Mounting**: Both the Woodpecker server and agent mount `/var/run/docker.sock` with write access, which grants root-equivalent access to the host system. This is necessary for pipeline execution but means that anyone with write access to Woodpecker can execute arbitrary containers on the host. Ensure proper access controls are configured in Woodpecker and limit write access to trusted users only.

## Troubleshooting

### OAuth2 authorization failing

1. Verify Forgejo OAuth2 application settings in Forgejo UI
2. Check `WOODPECKER_GITEA_URL` points to correct Forgejo instance
3. Verify `WOODPECKER_HOST` matches the redirect URI in Forgejo

### Pipelines not triggering

1. Enable repository in Woodpecker UI (Settings > Repositories)
2. Check `.woodpecker.yml` syntax (run `woodpecker-cli` locally to validate)
3. Verify webhook is configured (should be automatic after enabling repo)

### Docker socket access issues

1. Verify `/var/run/docker.sock` is mounted in both server and agent
2. Check Woodpecker agent can communicate with Docker daemon
3. Verify Docker group permissions on NAS host if needed

### Network connectivity

- Server: `ws://woodpecker-server:8000` (internal network for agent communication)
- External: `https://ci.in.hypyr.space` (via Caddy reverse proxy)
