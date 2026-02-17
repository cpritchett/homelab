# TrueNAS Scale Permissions Reference Guide

This guide provides comprehensive information about user permissions, ACLs, and troubleshooting for the homelab infrastructure on TrueNAS Scale.

## Overview

Docker containers run with specific UIDs/GIDs that must have proper permissions on the host filesystem. TrueNAS Scale uses ZFS with POSIX ACL support, allowing fine-grained access control.

## Service Account Mapping

| Service | Container User | Host UID | Host GID | Purpose |
|---------|---------------|----------|----------|---------|
| op-connect-api | opuser | 999 | 999 | 1Password Connect API |
| op-connect-sync | opuser | 999 | 999 | 1Password Connect Sync |
| komodo (core) | komodo | 568 | 568 | Komodo orchestration |
| komodo (mongo) | mongodb | 568 | 568 | MongoDB database |
| komodo (periphery) | komodo | 568 | 568 | Komodo agent |
| caddy | caddy | 1701 | 1702 | Reverse proxy |

## Directory Structure and Ownership

```
/mnt/apps01/
├── appdata/                    (755 root:root)
│   ├── op-connect/            (755 999:999)
│   ├── komodo/                (755 568:568)
│   │   ├── mongodb/           (700 568:568) ← Strict permissions
│   │   ├── sync/              (755 568:568)
│   │   ├── backups/           (755 568:568)
│   │   ├── secrets/           (770 568:568) ← Group writable
│   │   └── periphery/         (755 568:568)
│   └── proxy/                 (755 1701:1702)
│       ├── caddy-data/        (700 1701:1702) ← Strict permissions
│       ├── caddy-config/      (755 1701:1702)
│       └── caddy-secrets/     (700 1701:1702)
├── secrets/                   (750 root:root)
│   ├── op/                    (700 root:root + ACLs)
│   │   ├── 1password-credentials.json  (600 + ACL u:999:r--)
│   │   └── connect-token               (600 + ACL u:568:r--, u:999:r--)
│   └── cloudflare/            (700 root:root + ACLs)
│       └── api-token          (600 + ACL u:1701:r--)
└── repos/                     (755 root:docker)
    └── homelab/               (755 root:docker)
```

## ZFS Dataset Configuration

### Required ZFS Properties

```bash
# Enable POSIX ACLs (required for setfacl/getfacl)
zfs set acltype=posixacl apps01/appdata
zfs set acltype=posixacl apps01/secrets

# Set ACL inheritance mode
zfs set aclinherit=passthrough apps01/appdata
zfs set aclinherit=passthrough apps01/secrets

# Ensure case sensitivity (important for Docker volumes)
zfs set casesensitivity=sensitive apps01/appdata
zfs set casesensitivity=sensitive apps01/repos

# Disable access time updates (performance)
zfs set atime=off apps01/appdata
zfs set atime=off data01/data

# Verify settings
zfs get acltype,aclinherit,casesensitivity,atime apps01/appdata
```

### Recommended ZFS Tuning

```bash
# Set recordsize for database workloads (MongoDB)
zfs set recordsize=16K apps01/appdata/komodo/mongodb

# Set recordsize for large files (media)
zfs set recordsize=1M data01/data

# Enable compression (saves space, minimal CPU impact)
zfs set compression=lz4 apps01/appdata
zfs set compression=lz4 apps01/secrets

# Set quota to prevent runaway storage usage (optional)
zfs set quota=100G apps01/appdata/komodo/mongodb
zfs set quota=50G apps01/appdata/proxy/caddy-data
```

## Complete Setup Script

Use this script for initial permissions setup:

```bash
#!/bin/bash
###############################################################################
# TrueNAS Permissions Setup Script
# Run this script once before deploying infrastructure tier
###############################################################################

set -euo pipefail

echo "=== Creating Service Users and Groups ==="

# Create groups
groupadd -g 568 komodo 2>/dev/null || echo "Group 'komodo' already exists"
groupadd -g 999 opuser 2>/dev/null || echo "Group 'opuser' already exists"
groupadd -g 1701 caddy 2>/dev/null || echo "Group 'caddy' already exists"
groupadd -g 1702 caddyshared 2>/dev/null || echo "Group 'caddyshared' already exists"

# Create users
useradd -u 568 -g 568 -m -s /bin/bash komodo 2>/dev/null || echo "User 'komodo' already exists"
useradd -u 999 -g 999 -m -s /bin/bash opuser 2>/dev/null || echo "User 'opuser' already exists"
useradd -u 1701 -g 1701 -m -s /bin/bash caddy 2>/dev/null || echo "User 'caddy' already exists"

# Add to docker group
usermod -aG docker komodo
usermod -aG docker opuser
usermod -aG docker caddy

echo "=== Configuring ZFS Datasets ==="

# Set ZFS properties
zfs set acltype=posixacl apps01/appdata
zfs set acltype=posixacl apps01/secrets
zfs set acltype=posixacl apps01/repos
zfs set acltype=posixacl data01/data

zfs set aclinherit=passthrough apps01/appdata
zfs set aclinherit=passthrough apps01/secrets
zfs set aclinherit=passthrough data01/data

zfs set casesensitivity=sensitive apps01/appdata
zfs set casesensitivity=sensitive apps01/repos
zfs set casesensitivity=sensitive data01/data

zfs set atime=off apps01/appdata
zfs set atime=off data01/data

zfs set compression=lz4 apps01/appdata
zfs set compression=lz4 apps01/secrets

echo "=== Creating Directory Structure ==="

# Create base directories
mkdir -p /mnt/apps01/appdata/{op-connect,komodo,proxy}
mkdir -p /mnt/apps01/appdata/komodo/{mongodb,sync,backups,secrets,periphery}
mkdir -p /mnt/apps01/appdata/proxy/{caddy-data,caddy-config,caddy-secrets}
mkdir -p /mnt/apps01/secrets/{op,cloudflare}
mkdir -p /mnt/apps01/repos
mkdir -p /mnt/data01/data

echo "=== Setting Base Ownership ==="

# Set ownership
chown -R 999:999 /mnt/apps01/appdata/op-connect
chown -R 568:568 /mnt/apps01/appdata/komodo
chown -R 1701:1702 /mnt/apps01/appdata/proxy
chown -R root:root /mnt/apps01/secrets
chown -R root:docker /mnt/apps01/repos

echo "=== Setting Base Permissions ==="

# Base directory permissions
chmod 755 /mnt/apps01/appdata
chmod 750 /mnt/apps01/secrets
chmod 755 /mnt/apps01/repos

# Service directories
chmod 755 /mnt/apps01/appdata/op-connect
chmod 755 /mnt/apps01/appdata/komodo
chmod 755 /mnt/apps01/appdata/proxy

# Strict permissions for sensitive data
chmod 700 /mnt/apps01/appdata/komodo/mongodb
chmod 700 /mnt/apps01/appdata/proxy/caddy-data
chmod 770 /mnt/apps01/appdata/komodo/secrets

# Secret directories
chmod 700 /mnt/apps01/secrets/op
chmod 700 /mnt/apps01/secrets/cloudflare

echo "=== Configuring ACLs on Secrets ==="

# Note: Secret files must be created before ACLs can be set
# Run these commands after copying secret files to TrueNAS

if [ -f /mnt/apps01/secrets/op/1password-credentials.json ]; then
    chmod 600 /mnt/apps01/secrets/op/1password-credentials.json
    chown root:root /mnt/apps01/secrets/op/1password-credentials.json
    setfacl -m u:999:r-- /mnt/apps01/secrets/op/1password-credentials.json
    echo "✓ ACL set for 1password-credentials.json"
else
    echo "⚠ Skipping 1password-credentials.json (file not found)"
fi

if [ -f /mnt/apps01/secrets/op/connect-token ]; then
    chmod 600 /mnt/apps01/secrets/op/connect-token
    chown root:root /mnt/apps01/secrets/op/connect-token
    setfacl -m u:999:r-- /mnt/apps01/secrets/op/connect-token
    setfacl -m u:568:r-- /mnt/apps01/secrets/op/connect-token
    echo "✓ ACL set for connect-token"
else
    echo "⚠ Skipping connect-token (file not found)"
fi

if [ -f /mnt/apps01/secrets/cloudflare/api-token ]; then
    chmod 600 /mnt/apps01/secrets/cloudflare/api-token
    chown root:root /mnt/apps01/secrets/cloudflare/api-token
    setfacl -m u:1701:r-- /mnt/apps01/secrets/cloudflare/api-token
    echo "✓ ACL set for cloudflare api-token"
else
    echo "⚠ Skipping cloudflare/api-token (file not found)"
fi

# Set directory execute permissions for traversal
chmod 750 /mnt/apps01/secrets/op
chmod 750 /mnt/apps01/secrets/cloudflare
setfacl -m u:999:r-x /mnt/apps01/secrets/op
setfacl -m u:568:r-x /mnt/apps01/secrets/op
setfacl -m u:1701:r-x /mnt/apps01/secrets/cloudflare

echo "=== Setting Default ACLs ==="

# Default ACLs for new files in komodo directory
setfacl -d -m u::rwx /mnt/apps01/appdata/komodo
setfacl -d -m g::r-x /mnt/apps01/appdata/komodo
setfacl -d -m o::--- /mnt/apps01/appdata/komodo

echo "=== Verifying Docker Socket ==="

chmod 660 /var/run/docker.sock
chown root:docker /var/run/docker.sock

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Run the following to verify permissions:"
echo "  /tmp/verify-permissions.sh"
echo ""
echo "Next steps:"
echo "  1. Copy secret files to /mnt/apps01/secrets/"
echo "  2. Re-run this script to set ACLs on secret files"
echo "  3. Run verification script"
echo "  4. Proceed with bootstrap deployment"
```

Save this as `/mnt/apps01/scripts/setup-permissions.sh` and run it.

## ACL Reference

### Understanding ACL Entries

ACL format: `type:qualifier:permissions`

**Types:**
- `user` (u) - Specific user permissions
- `group` (g) - Specific group permissions
- `mask` (m) - Maximum permissions for named users/groups
- `other` (o) - Everyone else

**Common Permission Sets:**
- `r--` - Read only
- `r-x` - Read and execute (traverse directories)
- `rwx` - Full control
- `---` - No access

### Setting ACLs

```bash
# Grant user 999 read access to a file
setfacl -m u:999:r-- /path/to/file

# Grant user 568 read+execute access to directory (traversal)
setfacl -m u:568:r-x /path/to/directory

# Remove specific ACL entry
setfacl -x u:999 /path/to/file

# Remove all ACLs (revert to standard permissions)
setfacl -b /path/to/file

# Copy ACLs from one file to another
getfacl /source/file | setfacl --set-file=- /dest/file

# Set default ACLs (inherited by new files)
setfacl -d -m u:568:rwx /path/to/directory
```

### Viewing ACLs

```bash
# Show all ACLs for a file
getfacl /path/to/file

# Show ACLs without comments
getfacl --omit-header /path/to/file

# Show ACLs for all files in directory
getfacl -R /path/to/directory

# Check for files with ACLs (+ in ls output)
ls -la /mnt/apps01/secrets/op/
# -rw-------+ indicates ACLs present
```

## Troubleshooting

### Common Issues and Solutions

#### 1. "Permission denied" Reading Secret Files

**Symptom:** Container logs show "Permission denied: /run/secrets/..."

**Diagnosis:**
```bash
# Check file ownership
ls -l /mnt/apps01/secrets/op/1password-credentials.json

# Check ACLs
getfacl /mnt/apps01/secrets/op/1password-credentials.json

# Test as service user
sudo -u '#999' cat /mnt/apps01/secrets/op/1password-credentials.json
```

**Solution:**
```bash
# Fix ownership
chown root:root /mnt/apps01/secrets/op/1password-credentials.json
chmod 600 /mnt/apps01/secrets/op/1password-credentials.json

# Fix ACLs
setfacl -m u:999:r-- /mnt/apps01/secrets/op/1password-credentials.json

# Ensure parent directory is traversable
chmod 750 /mnt/apps01/secrets/op
setfacl -m u:999:r-x /mnt/apps01/secrets/op
```

#### 2. MongoDB "Data directory not writable"

**Symptom:** MongoDB container fails to start with permission error

**Diagnosis:**
```bash
ls -ld /mnt/apps01/appdata/komodo/mongodb
stat /mnt/apps01/appdata/komodo/mongodb
sudo -u '#568' test -w /mnt/apps01/appdata/komodo/mongodb && echo "OK" || echo "FAIL"
```

**Solution:**
```bash
# Fix ownership and permissions
chown -R 568:568 /mnt/apps01/appdata/komodo/mongodb
chmod 700 /mnt/apps01/appdata/komodo/mongodb

# Remove any restrictive ACLs
setfacl -b /mnt/apps01/appdata/komodo/mongodb

# Verify
sudo -u '#568' touch /mnt/apps01/appdata/komodo/mongodb/.test
sudo -u '#568' rm /mnt/apps01/appdata/komodo/mongodb/.test
```

#### 3. "Cannot access Docker socket"

**Symptom:** Komodo periphery or containers cannot interact with Docker

**Diagnosis:**
```bash
ls -l /var/run/docker.sock
groups komodo | grep docker
sudo -u komodo docker ps
```

**Solution:**
```bash
# Fix socket permissions
chmod 660 /var/run/docker.sock
chown root:docker /var/run/docker.sock

# Add user to docker group
usermod -aG docker komodo

# User must log out/in or restart services for group membership to take effect
# For immediate effect without logout:
newgrp docker
```

#### 4. ACLs Not Working

**Symptom:** ACLs don't seem to apply

**Diagnosis:**
```bash
# Check if dataset has ACL support
zfs get acltype apps01/appdata

# Check mount options
mount | grep apps01
```

**Solution:**
```bash
# Enable ACLs on dataset
zfs set acltype=posixacl apps01/appdata
zfs set aclinherit=passthrough apps01/appdata

# Remount dataset
zfs unmount apps01/appdata
zfs mount apps01/appdata

# Verify
zfs get acltype apps01/appdata
```

#### 5. "Operation not permitted" Despite Correct Permissions

**Symptom:** Operations fail even with correct ownership/permissions

**Diagnosis:**
```bash
# Check for immutable flags
lsattr /mnt/apps01/appdata/komodo/mongodb

# Check for SELinux (unlikely on TrueNAS)
getenforce

# Check ZFS properties
zfs get readonly,mountpoint apps01/appdata
```

**Solution:**
```bash
# Remove immutable flag if present
chattr -i /mnt/apps01/appdata/komodo/mongodb

# Ensure dataset is not readonly
zfs set readonly=off apps01/appdata

# Check if filesystem is full
df -h /mnt/apps01
```

## Verification Scripts

### Quick Permission Test

```bash
#!/bin/bash
# Quick test of critical permissions

echo "Testing service account permissions..."

tests_passed=0
tests_failed=0

test_permission() {
    local user=$1
    local path=$2
    local mode=$3  # r=read, w=write, x=execute

    case $mode in
        r) sudo -u "#$user" test -r "$path" ;;
        w) sudo -u "#$user" test -w "$path" ;;
        x) sudo -u "#$user" test -x "$path" ;;
    esac

    if [ $? -eq 0 ]; then
        echo "✓ User $user can $mode $path"
        ((tests_passed++))
    else
        echo "✗ User $user CANNOT $mode $path"
        ((tests_failed++))
    fi
}

# op-connect (999) tests
test_permission 999 /mnt/apps01/secrets/op/1password-credentials.json r
test_permission 999 /mnt/apps01/secrets/op/connect-token r
test_permission 999 /mnt/apps01/appdata/op-connect w

# komodo (568) tests
test_permission 568 /mnt/apps01/secrets/op/connect-token r
test_permission 568 /mnt/apps01/appdata/komodo w
test_permission 568 /mnt/apps01/appdata/komodo/mongodb w
test_permission 568 /mnt/apps01/appdata/komodo/secrets w

# caddy (1701) tests
test_permission 1701 /mnt/apps01/secrets/cloudflare/api-token r
test_permission 1701 /mnt/apps01/appdata/proxy w
test_permission 1701 /mnt/apps01/appdata/proxy/caddy-data w

echo ""
echo "Results: $tests_passed passed, $tests_failed failed"
[ $tests_failed -eq 0 ] && echo "✓ All permission tests passed" || echo "✗ Some tests failed - review above"
```

### Comprehensive ACL Audit

```bash
#!/bin/bash
# Comprehensive ACL audit

echo "=== ACL Audit Report ==="
echo ""

echo "--- Secret Files ---"
for file in /mnt/apps01/secrets/op/* /mnt/apps01/secrets/cloudflare/*; do
    if [ -f "$file" ]; then
        echo "File: $file"
        ls -l "$file"
        getfacl --omit-header "$file" 2>/dev/null | grep -E '^user:|^group:' || echo "  No ACLs"
        echo ""
    fi
done

echo "--- Application Data Directories ---"
for dir in /mnt/apps01/appdata/*; do
    echo "Directory: $dir"
    ls -ld "$dir"
    getfacl --omit-header "$dir" 2>/dev/null | grep -E '^user:|^group:|^default:' || echo "  No ACLs"
    echo ""
done

echo "--- Docker Socket ---"
ls -l /var/run/docker.sock
stat -c 'Permissions: %a Owner: %U:%G' /var/run/docker.sock
echo ""

echo "--- ZFS Properties ---"
zfs get acltype,aclinherit apps01/appdata apps01/secrets
```

## Best Practices

1. **Always use ACLs for cross-user file access** - Don't rely on group permissions alone
2. **Set directory execute (x) permissions for traversal** - Users need `r-x` on parent directories to access files
3. **Use 700 for sensitive data directories** - MongoDB data, TLS certificates should be user-only
4. **Use 770 for shared writable directories** - Allow group write where needed (e.g., secrets directory)
5. **Test permissions as the service user** - Always verify with `sudo -u '#UID' ...`
6. **Document custom ACLs** - Track what ACLs exist and why
7. **Use default ACLs for consistent inheritance** - Set once, applies to all new files
8. **Backup ACLs with getfacl** - Include in backup procedures
9. **Minimize root-owned writable directories** - Containers should not write to root-owned paths
10. **Audit regularly** - Check for permission drift over time

## References

- [POSIX ACLs Documentation](https://www.usenix.org/legacy/events/usenix03/tech/freenix03/full_papers/gruenbacher/gruenbacher_html/)
- [ZFS ACL Documentation](https://openzfs.github.io/openzfs-docs/man/7/zfsprops.7.html)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [TrueNAS Scale Documentation](https://www.truenas.com/docs/scale/)
