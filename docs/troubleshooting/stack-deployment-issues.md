# Docker Swarm Stack Deployment Issues and Solutions

This document tracks issues encountered when deploying Docker stacks with 1password Connect for secrets management and their solutions.

## Issue: Secrets File Permission Denied

### Symptom
Containers fail to read secrets files with error:
```
/bin/sh: 1: .: cannot open /secrets/authentik.env: Permission denied
```

### Root Cause
ZFS filesystem with NFSv4 ACLs requires proper permission inheritance for containers running as non-root users:

1. **1password/op container** runs as `uid=999` (opuser)
2. **authentik container** runs as `uid=1000` (authentik)
3. Files created by 1password container inherit `netdata:docker` ownership
4. ZFS with `posixacl` and `nfs4acl` requires execute permission on directories for traversal

### Solution
Update `secrets-init` command to fix permissions after injecting secrets:

```yaml
command: >
  sh -c "
  export OP_CONNECT_TOKEN=$$(cat /run/secrets/op_connect_token) &&
  op inject -i /templates/authentik.template -o /secrets/authentik.env -f &&
  op inject -i /templates/postgres.template -o /secrets/postgres.env -f &&
  chmod 600 /secrets/*.env &&
  chmod 700 /secrets &&
  echo 'Secrets injected successfully'
  "
```

### Key Permission Requirements
- Secrets directory: `700` (owner-only access with execute for traversal)
- Secrets files: `600` (owner-only read/write)
- Group: Set appropriately for container users (999, 1000, etc.)

### Manual Fix (if stack already deployed)
```bash
# Fix directory permissions
sudo chmod 700 /mnt/apps01/appdata/*/secrets

# Fix file permissions
sudo chmod 600 /mnt/apps01/appdata/*/secrets/*.env

# Fix ownership if needed (for uid 1000)
sudo chgrp 1000 /mnt/apps01/appdata/*/secrets
```

## Issue: PostgreSQL 18 Data Directory Path

### Symptom
PostgreSQL 18 container fails with:
```
Error: in 18+, these Docker images are configured to store database data in a format which is compatible with pg_ctlcluster...
```

### Root Cause
PostgreSQL 18 changed the expected data directory layout. The container expects `/var/lib/postgresql` (creates version-specific subdirectory internally), not `/var/lib/postgresql/data`.

### Solution
Update volume mount in compose file:

```yaml
# Before (PostgreSQL 17 and earlier)
volumes:
  - /mnt/apps01/appdata/authentik/postgres:/var/lib/postgresql/data

# After (PostgreSQL 18+)
volumes:
  - /mnt/apps01/appdata/authentik/postgres:/var/lib/postgresql
```

### Affected Stacks
- `stacks/platform/auth/authentik/compose.yaml`
- `stacks/platform/cicd/forgejo/compose.yaml`

## Issue: 1password op inject Interactive Prompts

### Symptom
Secrets injection fails with:
```
cannot prompt for confirmation. Use the '-f' or '--force' flag to skip confirmation.
```

### Root Cause
The 1password/op container runs non-interactively and cannot prompt for confirmation when injecting secrets.

### Solution
Add `-f` (force) flag to all `op inject` commands:

```yaml
command: >
  sh -c "
  export OP_CONNECT_TOKEN=$$(cat /run/secrets/op_connect_token) &&
  op inject -i /templates/authentik.template -o /secrets/authentik.env -f &&
  op inject -i /templates/postgres.template -o /secrets/postgres.env -f &&
  echo 'Secrets injected successfully'
  "
```

## General Permission Checklist for New Deployments

When deploying stacks with secrets initialization:

1. **Create secrets directories with proper permissions:**
   ```bash
   mkdir -p /mnt/apps01/appdata/{authentik,forgejo,komodo,restic,woodpecker}/secrets
   chmod 700 /mnt/apps01/appdata/*/secrets
   ```

2. **Ensure ZFS ACLs allow access:**
   - Directories need `x` (execute) permission for traversal
   - Files need `r` (read) permission for container users
   - Use `namei -l <path>` to debug permission chains

3. **Test secrets injection manually:**
   ```bash
   # Run secrets-init and check logs
   sudo docker service logs <stack>_secrets-init

   # Verify file permissions
   ls -la /mnt/apps01/appdata/<app>/secrets/

   # Test read access from container
   sudo docker run --rm -v /mnt/apps01/appdata/<app>/secrets:/secrets:ro \
     <app-image> cat /secrets/<app>.env
   ```

## Files Modified

| File | Change |
|------|--------|
| `stacks/platform/auth/authentik/compose.yaml` | Added `-f` flag, chmod commands, fixed PG path |
| `stacks/platform/cicd/forgejo/compose.yaml` | Fixed PG data path |
| `stacks/platform/cicd/woodpecker/compose.yaml` | Added `-f` flag |
| `stacks/platform/cicd/restic/compose.yaml` | Added `-f` flag |
| `stacks/platform/ingress/caddy/compose.yaml` | Added `-f` flag |
| `stacks/platform/komodo/compose.yaml` | Added `-f` flag |

## Related Documentation

- [1password Connect Documentation](https://developer.1password.com/docs/connect)
- [PostgreSQL Docker Image](https://github.com/docker-library/postgres)
- [ZFS on Linux ACLs](https://github.com/zfsonlinux/zfs/wiki/ZFS-on-Linux-ACL-Permissions)
- [Docker Swarm Secrets](https://docs.docker.com/engine/swarm/secrets/)
