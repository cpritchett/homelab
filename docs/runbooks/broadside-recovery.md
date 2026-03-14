# Broadside Recovery Runbook

This runbook documents how broadside supports recovery without becoming a second always-on authority plane.

## Principles

- Broadside is a recovery anchor, not a platform failover cluster.
- Normal LAN DNS remains on the router or upstream.
- Step-CA remains authoritative on barbary during normal operation.
- Broadside only promotes mutable services through explicit operator action.
- Prefer read-only and static services to be always available; prefer restore-over-HA for mutable authority services.

## Broadside Core Inventory

Broadside should be able to provide the following even when barbary is down:

- SSH
- Tailscale
- Unbound forwarding/cache
- Caddy static runbook site
- read-only mirror of the homelab repo and critical config

Optional services:

- Step-CA restore target
- dnsmasq + Matchbox
- Uptime Kuma

## Scenario 1: Routine Readiness Check

Use this regularly to confirm broadside is actually useful before an outage.

### Goals

- broadside is reachable
- core services are healthy
- mirrored docs and repo are current
- latest Step-CA backup archive exists

### Commands

```bash
./scripts/recovery-check-broadside.sh
```

To create or refresh a Step-CA backup archive from barbary:

```bash
./scripts/recovery-backup-step-ca.sh --from-host root@barbary
```

### Success Criteria

- SSH succeeds
- runbook site responds
- repo mirror path exists
- deployed repo snapshot exists even if live git remotes are down
- Unbound is reachable
- latest Step-CA archive is present under the configured backup directory

## Scenario 2: Barbary Down, Documentation and Access Needed

This is the most common broadside scenario.

### Goals

- regain an operational foothold
- access current runbooks
- access mirrored repo/config
- avoid changing authority unless necessary

### Procedure

1. Reach broadside over Tailscale or its LAN address.
2. Log in over SSH.
3. Validate core services:

```bash
./scripts/recovery-check-broadside.sh --host root@broadside
```

4. Use the Caddy-served runbook site and mirror directly.
5. Continue barbary recovery from broadside without changing DNS for the rest of the LAN.

### Notes

- Do not change router DNS yet.
- Do not restore Step-CA yet unless certificate issuance is actually required for the next recovery step.

## Scenario 3: Broadside DNS Needed for Recovery Clients

Use this only when operator systems or specific recovery clients need a working resolver independent of barbary.

### Goals

- use broadside as a scoped secondary resolver
- keep the rest of the LAN on the normal router DNS path

### Procedure

1. Verify broadside Unbound is healthy:

```bash
./scripts/recovery-query-broadside-dns.sh broadside.in.hypyr.space
```

2. Temporarily point only the operator workstation or targeted recovery host at broadside's resolver.
3. Re-test resolution for the recovery names you need.

### Recommended Scope

Use broadside for:

- operator workstation
- temporary rescue VM
- rebuilt host during first bootstrapping steps

Do not use broadside as the whole-LAN primary resolver by default.

### Rollback

- revert the client resolver back to the router/upstream DNS once the recovery action is complete

## Scenario 4: Barbary Down and Internal PKI Needed

This is the only case where Step-CA should be restored onto broadside.

### When to Use

Use this scenario only if recovery work requires certificate issuance or a trusted internal CA endpoint. Examples:

- rebuilding a service that must present a Smallstep-issued certificate
- reissuing a certificate that expired during the outage
- recovering tooling that depends on the trusted internal CA

### Preconditions

- broadside is reachable
- a recent Step-CA backup archive exists
- broadside has the configured restore target directory available
- you understand that broadside is becoming the temporary CA host

### Restore Procedure

1. Confirm the archive you want to use:

```bash
ls -lh /srv/recovery/backups/step-ca/
```

2. Restore the Step-CA state archive to broadside:

```bash
./scripts/recovery-restore-step-ca-on-broadside.sh \
  --archive /srv/recovery/backups/step-ca/step-ca-backup-latest.tgz \
  --target-host root@broadside \
  --target-dir /srv/recovery/appdata/step-ca \
  --apply
```

3. Start or restart the broadside Step-CA service using the broadside host configuration or compose unit.
4. Verify health locally on broadside.
5. Only then repoint selected clients or tooling to the broadside CA endpoint on port `9000`.

### Verification

```bash
ssh root@broadside 'step ca health --ca-url https://localhost:9000 --root /srv/recovery/appdata/step-ca/certs/root_ca.crt'
```

Verify the recovered CA serves the expected root and can issue a test certificate before using it in recovery workflows.

### Naming

Prefer a recovery-specific name, such as:

- `ca-broadside.in.hypyr.space:9000`

Do not silently assume the primary CA name unless you intentionally repoint the relevant clients.

### Rollback

- once barbary is healthy again, return Step-CA authority to barbary
- stop the temporary Step-CA instance on broadside
- preserve logs and any incident notes

## Scenario 5: PXE / Bootstrap Needed While Barbary Is Healthy

Use barbary's existing PXE and Matchbox stack to bootstrap or reinstall broadside.

### Goals

- keep one normal PXE authority day to day
- use the existing barbary-hosted PXE path for broadside installation

### Procedure

1. Update the broadside PXE selector and asset path on barbary.
2. Build the Broadside netboot assets from the repo flake on a machine with either local `nix` or Docker available:

```bash
./scripts/build-broadside-installer-assets.sh
```

For ad hoc flake inspection or builds without installing Nix system-wide:

```bash
./scripts/nix-in-docker.sh flake show "path:$PWD"
```

This build now vendors:

- the exact repo snapshot being installed
- the `disko` flake input
- the `nixpkgs` flake input
- rewritten iPXE assets pointing at barbary's local PXE asset path

3. Sync the generated assets to barbary:

```bash
./scripts/sync-broadside-installer-assets.sh
```

4. Validate PXE prerequisites with Broadside assets enabled:

```bash
PXE_ENABLE_BROADSIDE=1 ./scripts/validate-pxe-setup.sh
```

5. Boot broadside from the network.
6. At the installer console, run:

```bash
/root/install-broadside.sh
```

The installer pulls only from barbary's local PXE asset path and does not clone the homelab repo from GitHub during install.

The generated asset bundle also carries the flake-locked `nixpkgs` and `disko` sources, so install uses the same pinned inputs that produced the PXE artifacts.

7. After successful install, switch broadside back to local boot.

### Notes

- this is the default bootstrap path
- broadside uses a dedicated iPXE asset path under the existing barbary PXE stack
- broadside-hosted PXE remains optional, not primary

## Scenario 6: PXE Independence Needed Later

If barbary is unavailable and PXE services are required for additional rebuilds, broadside may later activate `dnsmasq + Matchbox`.

This is a deliberate promotion, not a day-to-day default.

### Requirements

- broadside already healthy
- broadside has mirrored PXE assets and configs
- operator intentionally enables PXE helper services on broadside

### Warning

Do not run two competing proxyDHCP authorities casually. Promote broadside PXE only when barbary is no longer serving that role or when the scope is tightly controlled.

## Step-CA Backup Cadence

Maintain a recent Step-CA backup archive on broadside.

### Recommended Workflow

1. Periodically archive the barbary Step-CA state directory:

```bash
./scripts/recovery-backup-step-ca.sh \
  --from-host root@barbary \
  --source-dir /mnt/apps01/appdata/step-ca \
  --backup-dir /srv/recovery/backups/step-ca
```

2. Keep a `step-ca-backup-latest.tgz` symlink or copy.
3. Periodically test a restore drill onto a disposable path or recovery host.

## Incident Checklist

- [ ] Broadside reachable over LAN or Tailscale
- [ ] Runbook site available
- [ ] Repo mirror available
- [ ] Recovery DNS works when queried directly
- [ ] Latest Step-CA backup archive present
- [ ] Step-CA restored only if required
- [ ] Any temporary DNS or service promotion is explicitly rolled back

## Related Scripts

- `scripts/recovery-check-broadside.sh`
- `scripts/recovery-query-broadside-dns.sh`
- `scripts/recovery-backup-step-ca.sh`
- `scripts/recovery-restore-step-ca-on-broadside.sh`

## Related Documentation

- [Broadside Recovery Node](../architecture/broadside.md)
- [Disaster Recovery](./disaster-recovery.md)
- [Break-glass](./break-glass.md)
