# Authentication Stack Deployment Guide

This guide covers deploying the Authentik authentication system for homelab NAS services.

## Prerequisites

1. **Proxy stack deployed** - Caddy must be running
2. **1Password secrets configured** - Auth credentials must be available
3. **Network connectivity** - Authentik containers need internet access for initial setup

## Deployment Steps

### 1. Deploy Authentik Stack

```bash
# Deploy the authentication stack
cd /mnt/apps01/appdata/stacks/homelab/stacks
./_bin/deploy-stack authentik

# Verify deployment
sudo docker compose -f authentik/compose.yml ps
```

### 2. Initial Configuration

1. **Access Bootstrap UI**
   ```
   https://auth.in.hypyr.space/if/flow/initial-setup/
   ```

2. **Use Bootstrap Credentials**
   - Username: `akadmin`
   - Password: From 1Password (`AUTHENTIK_BOOTSTRAP_PASSWORD`)

3. **Complete Initial Setup**
   - Set permanent admin password
   - Configure default tenant settings
   - Create user groups as needed

### 3. Configure Forward Auth Outpost

1. **Navigate to Admin Interface**
   ```
   https://auth.in.hypyr.space/if/admin/
   ```

2. **Create Forward Auth Provider**
   - Applications → Providers → Create
   - Type: "Proxy Provider"
   - Name: "Caddy Forward Auth"
   - Authorization flow: "default-provider-authorization-implicit-consent"
   - Forward auth (single application): ✓
   - External host: `https://auth.in.hypyr.space`

3. **Create Application**
   - Applications → Applications → Create
   - Name: "Homelab Services"
   - Slug: "homelab-services"
   - Provider: Select the provider created above

4. **Create Outpost**
   - Applications → Outposts → Create
   - Name: "Caddy Outpost"
   - Type: "Proxy"
   - Applications: Select "Homelab Services"

### 4. Deploy Protected Services

```bash
# Deploy Harbor with authentication
./_bin/deploy-stack harbor

# Deploy test service
./_bin/deploy-stack whoami

# Verify all services are running
./_bin/deploy-all
```

### 5. Test Authentication Flow

1. **Test Protected Service**
   ```
   curl -I https://whoami.in.hypyr.space
   # Should return 302 redirect to auth
   ```

2. **Test Health Endpoint**
   ```
   curl https://whoami.in.hypyr.space/health
   # Should return 200 OK without auth
   ```

3. **Test Web Interface**
   - Visit `https://whoami.in.hypyr.space`
   - Should redirect to Authentik login
   - After login, should show service response with auth headers

## Troubleshooting

### Authentik Won't Start

```bash
# Check container logs
sudo docker compose -f authentik/compose.yml logs authentik-server
sudo docker compose -f authentik/compose.yml logs authentik-postgres

# Check database connectivity
sudo docker compose -f authentik/compose.yml exec authentik-postgres pg_isready -U authentik

# Restart services
sudo docker compose -f authentik/compose.yml restart
```

### Forward Auth Not Working

1. **Check Outpost Configuration**
   - Verify outpost is running and healthy in Authentik admin
   - Check application and provider configuration

2. **Check Caddy Labels**
   ```bash
   # Verify labels are applied correctly
   sudo docker inspect harbor-proxy | grep -A 20 Labels
   ```

3. **Test Auth Endpoint Directly**
   ```bash
   curl -I http://authentik-server:9000/outpost.goauthentik.io/auth/caddy
   ```

### Emergency Access

If authentication is completely broken:

```bash
# Disable auth for all services
cd /mnt/apps01/appdata/stacks/homelab/stacks/authentik
./emergency-bypass.sh enable

# Fix the issue, then re-enable auth
./emergency-bypass.sh disable
```

## Security Considerations

1. **Bootstrap Credentials**
   - Change default admin password immediately
   - Disable bootstrap user after setup
   - Rotate bootstrap token regularly

2. **Network Security**
   - Authentik containers only accessible via proxy network
   - Database and Redis not exposed externally
   - Health endpoints minimal information disclosure

3. **Session Management**
   - Configure appropriate session timeouts
   - Enable MFA for admin accounts
   - Regular audit of user access

## Monitoring

### Health Checks

```bash
# Check all auth components
curl https://auth.in.hypyr.space/-/health/

# Check database
sudo docker compose -f authentik/compose.yml exec authentik-postgres pg_isready

# Check Redis
sudo docker compose -f authentik/compose.yml exec authentik-redis redis-cli ping
```

### Log Monitoring

```bash
# Monitor auth events
sudo docker compose -f authentik/compose.yml logs -f authentik-server | grep -E "(login|logout|auth)"

# Monitor forward auth requests
sudo docker compose -f proxy/compose.yml logs -f caddy | grep forward_auth
```

## Backup and Recovery

### Database Backup

```bash
# Backup Authentik database
sudo docker compose -f authentik/compose.yml exec authentik-postgres pg_dump -U authentik authentik > authentik-backup-$(date +%Y%m%d).sql
```

### Configuration Export

1. Export tenant configuration via Authentik admin UI
2. Store exported configuration in secure location
3. Document custom flows, policies, and applications

### Recovery Process

1. Deploy fresh Authentik stack
2. Restore database from backup
3. Import configuration
4. Verify all applications and outposts are working