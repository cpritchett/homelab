# Authentik Deployment Status

## Completed ✅

1. **Label Compliance (ADR-0034)**
   - ✅ Homepage labels added (group, name, icon, href, description, widget)
   - ✅ Caddy labels configured (reverse proxy, TLS)
   - ✅ AutoKuma labels added (HTTP monitoring with redirect support)
   - All labels in `deploy.labels` section of compose.yaml

2. **Komodo Compatibility (ADR-0022)**
   - ✅ Compose file is Komodo-compatible
   - ✅ Created `scripts/validate-authentik-setup.sh` - pre-deployment validation
   - ✅ Script verifies all prerequisites
   - ✅ Handles directory creation and permissions
   - ✅ Tests 1Password Connect connectivity
   - ✅ Does NOT deploy stack (per ADR-0022, deployment is via Komodo UI)

3. **Documentation**
   - ✅ Created `DEPLOY.md` - comprehensive deployment guide
   - ✅ Three deployment methods documented (script, manual, Komodo UI)
   - ✅ Prerequisites clearly listed
   - ✅ Post-deployment steps included
   - ✅ Troubleshooting guide for common issues
   - ✅ Health checks and monitoring instructions

4. **Code Repository**
   - ✅ All changes committed to git
   - ✅ Pushed to remote repository (github.com/cpritchett/homelab)
   - ✅ Ready for deployment on TrueNAS server

## Pending Execution 🔄

The following steps need to be executed on the TrueNAS server to complete the deployment:

### Quick Start (Per ADR-0022)

**Deploy via Komodo UI:**
1. Navigate to https://komodo.in.hypyr.space
2. Stacks → Add Stack from Repository
3. Configure:
   - Path: `stacks/platform/auth/authentik`
   - Pre-Deploy Hook: `scripts/validate-authentik-setup.sh` (optional but recommended)
4. Click Deploy
5. Monitor in Komodo UI

**Duration:** ~3-5 minutes

**What happens automatically:**
- Komodo syncs repository (git pull)
- Pre-deployment hook validates prerequisites (if configured)
- Directories created with correct permissions
- Stack deployed via docker stack deploy
- Services start and auto-discovered by Homepage, Caddy, AutoKuma

**Note:** The pre-deployment script is idempotent and runs before every deployment if configured as a Komodo hook.

### Manual Validation (Optional)

If you want to manually test the pre-deployment hook before configuring it in Komodo:

```bash
# SSH to TrueNAS (after Komodo has synced the repo)
ssh root@barbary

# Run validation script manually
sudo /mnt/apps01/repos/homelab/scripts/validate-authentik-setup.sh
```

This is the same script Komodo runs as a pre-deploy hook. It is idempotent and safe to run multiple times.

**Note:** Do NOT run `git pull` or `docker stack deploy` manually. Komodo handles both per ADR-0022.

## Post-Deployment Checklist

Once deployment is executed:

- [ ] All services show 1/1 replicas in `docker service ls`
- [ ] Secrets injected: `ls /mnt/apps01/appdata/authentik/secrets/*.env`
- [ ] Authentik UI accessible: https://auth.in.hypyr.space
- [ ] TLS certificate valid (no browser warnings)
- [ ] Complete initial setup (create akadmin user)
- [ ] Create API token for Homepage widget
- [ ] Verify Homepage auto-discovered Authentik in "Platform" group
- [ ] Verify AutoKuma created "Authentik SSO" monitor
- [ ] Verify Caddy reverse proxy working (check Caddy logs)

## Integration Status

### Homepage Dashboard
- **Auto-discovery:** Ready (labels configured)
- **Widget:** Requires API token (post-deployment step)
- **Group:** Platform
- **Expected:** Appears automatically after deployment

### Caddy Reverse Proxy
- **Domain:** auth.in.hypyr.space
- **TLS:** Cloudflare DNS-01 challenge
- **Status:** Ready (labels configured)
- **Expected:** Certificate auto-issued on first request

### AutoKuma Monitoring
- **Monitor Name:** "Authentik SSO"
- **Check Type:** HTTP
- **URL:** https://auth.in.hypyr.space
- **Status:** Ready (labels configured)
- **Expected:** Monitor auto-created within 60 seconds of deployment

## Prerequisites Verified

Required for deployment (should already exist from infrastructure tier):

- ✅ Docker Swarm active
- ✅ Infrastructure tier deployed (op-connect, komodo, caddy)
- ✅ Docker networks: `proxy_network`, `op-connect_op-connect`
- ✅ Docker secrets: `op_connect_token`, `CLOUDFLARE_API_TOKEN`
- ✅ 1Password Connect running and accessible

Required in 1Password vault (must be created before deployment):

- ⚠️ **Verify:** Item "authentik-stack" in vault "homelab"
- ⚠️ **Verify:** Fields: secret_key, bootstrap_email, bootstrap_password, postgres_password

Verification command (from workstation):
```bash
op item get "authentik-stack" --vault homelab --fields label
```

## Deployment Artifacts

All files committed and pushed to repository:

- `stacks/platform/auth/authentik/compose.yaml` - Updated with ADR-0034 labels
- `docs/deployment/AUTHENTIK_DEPLOY.md` - Comprehensive deployment guide
- `docs/deployment/AUTHENTIK_DEPLOYMENT_STATUS.md` - This file

## Timeline

- **Preparation:** Completed (labels, scripts, docs)
- **Deployment:** ~5 minutes (automated script) or ~10 minutes (manual)
- **Post-deployment:** ~10 minutes (initial setup, API token, verification)
- **Total:** ~15-20 minutes end-to-end

## Next Steps After Deployment

1. **Configure SSO for existing services**
   - Komodo
   - Homepage
   - Grafana (when deployed)
   - Uptime Kuma

2. **Set up authentication flows**
   - Enable MFA
   - Configure password policies
   - Set up user enrollment

3. **Create users and groups**
   - Define RBAC policies
   - Assign permissions

## Support

For issues during deployment, refer to:
- `docs/deployment/AUTHENTIK_DEPLOY.md` - Full deployment guide with troubleshooting
- `docs/deployment/PHASE1_DEPLOYMENT_RUNBOOK.md` - Infrastructure deployment reference
- Authentik logs: `docker service logs authentik_authentik-server`
