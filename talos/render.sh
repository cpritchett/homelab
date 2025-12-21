#!/usr/bin/env bash
set -euo pipefail

#===============================================================================
# Talos Configuration Renderer (ytt Data Values)
#===============================================================================
# Renders Talos configs using ytt data values pattern.
#
# Usage:
#   ./render.sh home01           # Render single node
#   ./render.sh all              # Render all nodes
#   ./render.sh --validate       # Render + validate all
#
# Requirements:
#   - ytt (https://carvel.dev/ytt/)
#
# Architecture:
#   templates/schema.yaml         # Data values schema (validation)
#   templates/base.yaml           # Main template with #@ data.values
#   values/{node}.yaml            # Node-specific data values
#   rendered/{node}.yaml          # Final rendered output
#
# See: ADR-0013 (ytt data values for Talos templating)
#===============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
VALUES_DIR="${SCRIPT_DIR}/values"
RENDERED_DIR="${SCRIPT_DIR}/rendered"

# All nodes to render
NODES=(home01 home02 home04 home05)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check dependencies
check_deps() {
    if ! command -v ytt &> /dev/null; then
        echo -e "${RED}ERROR: ytt not found${NC}"
        echo "Install: brew install ytt"
        exit 1
    fi
}

# Render a single node
render_node() {
    local node="$1"
    local values_file="${VALUES_DIR}/${node}.yaml"
    local output_file="${RENDERED_DIR}/${node}.yaml"

    if [[ ! -f "$values_file" ]]; then
        echo -e "${RED}ERROR: Values file not found: ${values_file}${NC}"
        return 1
    fi

    echo -e "${BLUE}Rendering${NC} ${node}..."

    # Render using ytt
    if ytt -f "${TEMPLATES_DIR}" --data-values-file "${values_file}" > "${output_file}"; then
        echo -e "  ${GREEN}✓${NC} ${output_file}"
        return 0
    else
        echo -e "  ${RED}✗${NC} Failed to render ${node}"
        return 1
    fi
}

# Validate a rendered config
validate_node() {
    local node="$1"
    local config_file="${RENDERED_DIR}/${node}.yaml"

    if [[ ! -f "$config_file" ]]; then
        echo -e "${RED}ERROR: Rendered config not found: ${config_file}${NC}"
        return 1
    fi

    echo -e "${BLUE}Validating${NC} ${node}..."

    # Note: talosctl validate will fail on op:// references
    # This is expected - validation happens after 1Password injection
    # For now, just check YAML syntax
    if ytt -f "${config_file}" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} YAML syntax valid"
        return 0
    else
        echo -e "  ${RED}✗${NC} YAML syntax invalid"
        return 1
    fi
}

# Render all nodes
render_all() {
    local failed=0

    mkdir -p "${RENDERED_DIR}"

    for node in "${NODES[@]}"; do
        if ! render_node "$node"; then
            ((failed++))
        fi
    done

    echo ""
    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}All nodes rendered successfully${NC}"
    else
        echo -e "${RED}${failed} node(s) failed to render${NC}"
        return 1
    fi
}

# Validate all nodes
validate_all() {
    local failed=0

    for node in "${NODES[@]}"; do
        if ! validate_node "$node"; then
            ((failed++))
        fi
    done

    echo ""
    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}All nodes validated successfully${NC}"
    else
        echo -e "${RED}${failed} node(s) failed validation${NC}"
        return 1
    fi
}

# Show usage
usage() {
    echo "Usage: $0 [node|all|--validate|--help]"
    echo ""
    echo "Commands:"
    echo "  <node>      Render a specific node (e.g., home01)"
    echo "  all         Render all nodes"
    echo "  --validate  Render and validate all nodes"
    echo "  --help      Show this help message"
    echo ""
    echo "Available nodes: ${NODES[*]}"
}

# Main
main() {
    check_deps

    case "${1:-all}" in
        --help|-h)
            usage
            ;;
        --validate)
            render_all && validate_all
            ;;
        all)
            render_all
            ;;
        *)
            # Check if it's a valid node
            local node="$1"
            local valid=false
            for n in "${NODES[@]}"; do
                if [[ "$n" == "$node" ]]; then
                    valid=true
                    break
                fi
            done

            if $valid; then
                mkdir -p "${RENDERED_DIR}"
                render_node "$node"
            else
                echo -e "${RED}ERROR: Unknown node: ${node}${NC}"
                echo "Available nodes: ${NODES[*]}"
                exit 1
            fi
            ;;
    esac
}

main "$@"
