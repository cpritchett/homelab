#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(git rev-parse --show-toplevel)
cd "$ROOT_DIR"

# Render templates
./talos/render.sh all

# Validate rendered configs
for node in home01 home02 home04 home05; do
  file="talos/rendered/${node}.yaml"
  if [[ ! -f "$file" ]]; then
    echo "❌ Missing: $file" >&2
    exit 1
  fi
  lines=$(wc -l < "$file")
  if [[ $lines -lt 100 ]]; then
    echo "❌ $file too short (${lines} lines)" >&2
    exit 1
  fi
  echo "✓ ${node}: ${lines} lines"
done

# Verify node differentiation
# home01
grep -q "hostname: home01.hypyr.space" talos/rendered/home01.yaml
grep -q "10.0.5.215/24" talos/rendered/home01.yaml
echo "✓ home01: hostname and IP correct"

# home04 (P520 - different hardware)
grep -q "hostname: home04.hypyr.space" talos/rendered/home04.yaml
grep -q "10.0.5.92/24" talos/rendered/home04.yaml
if grep -q "deviceSelectors:" talos/rendered/home04.yaml; then
  echo "❌ home04 should use interfaces, not deviceSelectors" >&2
  exit 1
fi
echo "✓ home04: hostname, IP, and bond config correct"

# Verify 1Password references preserved
count=$(grep -c "op://homelab/talos/" talos/rendered/home01.yaml || true)
if [[ $count -lt 13 ]]; then
  echo "❌ Expected ≥13 op:// references, found $count" >&2
  exit 1
fi
echo "✓ Found $count op:// references"

grep -q "op://homelab/talos/MACHINE_TOKEN" talos/rendered/home01.yaml
grep -q "op://homelab/talos/CLUSTER_CA_CRT" talos/rendered/home01.yaml
echo "✓ Critical secrets present"

# Verify multi-document output
for node in home01 home02 home04 home05; do
  file="talos/rendered/${node}.yaml"
  if ! grep -q "kind: VolumeConfig" "$file"; then
    echo "❌ ${node}: missing VolumeConfig" >&2
    exit 1
  fi
  if ! grep -q "kind: UserVolumeConfig" "$file"; then
    echo "❌ ${node}: missing UserVolumeConfig" >&2
    exit 1
  fi
  echo "✓ ${node}: multi-document structure valid"
done

# Verify VLANs on all nodes
for node in home01 home02 home04 home05; do
  vlan_count=$(grep -c "vlanId:" talos/rendered/${node}.yaml || true)
  if [[ $vlan_count -lt 2 ]]; then
    echo "❌ ${node}: expected ≥2 VLANs, found $vlan_count" >&2
    exit 1
  fi
  if ! grep -q "vlanId: 10" talos/rendered/${node}.yaml; then
    echo "❌ ${node}: missing VLAN 10" >&2
    exit 1
  fi
  if ! grep -q "vlanId: 48" talos/rendered/${node}.yaml; then
    echo "❌ ${node}: missing VLAN 48" >&2
    exit 1
  fi
  echo "✓ ${node}: has VLANs 10 and 48"
done
