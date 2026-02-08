#!/bin/bash
###############################################################################
# Phase 1 Infrastructure Validation Script
#
# Validates that all infrastructure tier services are running correctly
###############################################################################

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

passed=0
failed=0
warnings=0

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((passed++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((failed++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((warnings++))
}

echo "========================================="
echo "Phase 1 Infrastructure Validation"
echo "========================================="
echo ""

# Docker Swarm Validation
echo "=== Docker Swarm ==="
if docker info | grep -q "Swarm: active"; then
    check_pass "Docker Swarm is active"
    ADVERTISE_ADDR=$(docker info | grep "Advertise" | awk '{print $3}' || echo "unknown")
    if [ -n "$ADVERTISE_ADDR" ] && [ "$ADVERTISE_ADDR" != "unknown" ]; then
        echo "  Advertise address: $ADVERTISE_ADDR"
    fi
else
    check_fail "Docker Swarm is not active"
fi

if docker node ls | grep -q "Leader"; then
    check_pass "Node is Swarm manager (Leader)"
else
    check_fail "Node is not Swarm manager"
fi
echo ""

# Network Validation
echo "=== Overlay Networks ==="
if docker network inspect proxy_network >/dev/null 2>&1; then
    check_pass "proxy_network exists"
else
    check_fail "proxy_network missing"
fi

if docker network inspect op-connect_op-connect >/dev/null 2>&1; then
    check_pass "op-connect_op-connect exists"
else
    check_fail "op-connect_op-connect missing"
fi
echo ""

# Secrets Validation
echo "=== Swarm Secrets ==="
for secret in op_connect_token CLOUDFLARE_API_TOKEN komodo_db_password komodo_passkey; do
    if docker secret inspect $secret >/dev/null 2>&1; then
        check_pass "Secret exists: $secret"
    else
        check_fail "Secret missing: $secret"
    fi
done
echo ""

# Stack Validation
echo "=== Stacks Deployed ==="
for stack in op-connect komodo caddy; do
    if docker stack ls | grep -q "$stack"; then
        check_pass "Stack deployed: $stack"
    else
        check_fail "Stack missing: $stack"
    fi
done
echo ""

# Service Validation
echo "=== Services Running ==="
services=(
    "op-connect_op-connect-api:1/1"
    "op-connect_op-connect-sync:1/1"
    "komodo_core:1/1"
    "komodo_mongo:1/1"
    "komodo_periphery:1/1"
    "caddy_caddy:1/1"
    "caddy_docker-socket-proxy:1/1"
)

for service_check in "${services[@]}"; do
    service_name="${service_check%:*}"
    expected_replicas="${service_check#*:}"

    if docker service ls --format "{{.Name}} {{.Replicas}}" | grep -q "$service_name $expected_replicas"; then
        check_pass "Service running: $service_name ($expected_replicas)"
    else
        actual=$(docker service ls --format "{{.Name}} {{.Replicas}}" | grep "$service_name" | awk '{print $2}' || echo "not found")
        check_fail "Service issue: $service_name (expected $expected_replicas, got $actual)"
    fi
done
echo ""

# Service Health Checks
echo "=== Service Health ==="

# Check MongoDB
if docker exec $(docker ps -q -f name=komodo_mongo) mongosh --quiet --eval "db.adminCommand('ping')" 2>/dev/null | grep -q "ok.*1"; then
    check_pass "MongoDB is responding"
else
    check_fail "MongoDB health check failed"
fi

# Check Komodo Core
if docker exec $(docker ps -q -f name=komodo_core) curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1:30160/ 2>/dev/null | grep -q "200\|302"; then
    check_pass "Komodo Core is responding"
else
    check_fail "Komodo Core health check failed"
fi

# Check Caddy
if docker exec $(docker ps -q -f name=caddy_caddy) wget -qO- http://localhost:2019/config/ >/dev/null 2>&1; then
    check_pass "Caddy admin API is responding"
else
    check_warn "Caddy admin API check failed (may be normal)"
fi

# Check docker-socket-proxy
if docker exec $(docker ps -q -f name=docker-socket-proxy) wget -qO- http://localhost:2375/_ping 2>/dev/null | grep -q "OK"; then
    check_pass "Docker socket proxy is responding"
else
    check_fail "Docker socket proxy health check failed"
fi
echo ""

# External Accessibility
echo "=== External Access ==="
if curl -k -s -o /dev/null -w "%{http_code}" https://komodo.in.hypyr.space 2>/dev/null | grep -q "200\|302"; then
    check_pass "Komodo UI accessible via HTTPS"
else
    check_fail "Komodo UI not accessible externally"
fi
echo ""

# TLS Certificates
echo "=== TLS Certificates ==="
if docker exec $(docker ps -q -f name=caddy_caddy) ls /data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/ 2>/dev/null | grep -q "in.hypyr.space"; then
    check_pass "Let's Encrypt certificates present"
else
    check_warn "Let's Encrypt certificates not found (may still be provisioning)"
fi
echo ""

# Persistence Validation
echo "=== Data Persistence ==="
paths=(
    "/mnt/apps01/appdata/op-connect"
    "/mnt/apps01/appdata/komodo/mongodb"
    "/mnt/apps01/appdata/komodo/sync"
    "/mnt/apps01/appdata/komodo/backups"
    "/mnt/apps01/appdata/proxy/caddy-data"
    "/mnt/apps01/appdata/proxy/caddy-config"
)

for path in "${paths[@]}"; do
    if [ -d "$path" ]; then
        size=$(du -sh "$path" 2>/dev/null | awk '{print $1}')
        check_pass "Directory exists: $path ($size)"
    else
        check_fail "Directory missing: $path"
    fi
done
echo ""

# Summary
echo "========================================="
echo "Validation Summary"
echo "========================================="
echo -e "${GREEN}Passed:${NC} $passed"
if [ $warnings -gt 0 ]; then
    echo -e "${YELLOW}Warnings:${NC} $warnings"
fi
if [ $failed -gt 0 ]; then
    echo -e "${RED}Failed:${NC} $failed"
fi
echo ""

if [ $failed -eq 0 ]; then
    echo -e "${GREEN}✓ Phase 1 validation PASSED${NC}"
    echo "All critical infrastructure components are healthy"
    exit 0
else
    echo -e "${RED}✗ Phase 1 validation FAILED${NC}"
    echo "Please review failed checks above"
    exit 1
fi
