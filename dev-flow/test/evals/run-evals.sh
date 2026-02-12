#!/usr/bin/env bash
# =============================================================================
# dev-flow plugin - Evaluation Scenarios Runner
# =============================================================================
# This script provides instructions for running evaluation scenarios against
# the dev-flow plugin. Each scenario tests a different pipeline path through
# the orchestrator.
#
# Since these are Claude Code plugin evaluations, they run interactively
# through Claude Code. This script serves as a runner and documentation.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIOS_DIR="${SCRIPT_DIR}/scenarios"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    cat <<EOF
Usage: $(basename "$0") [command] [scenario]

Commands:
    list        List all available evaluation scenarios
    describe    Show details of a specific scenario
    help        Show this help message

Scenarios are run manually through Claude Code. This script helps you
understand what each scenario tests and how to verify it.

Examples:
    $(basename "$0") list
    $(basename "$0") describe health-endpoint
    $(basename "$0") describe dashboard-with-ui
    $(basename "$0") describe monorepo-feature

EOF
}

list_scenarios() {
    echo -e "${BLUE}Available Evaluation Scenarios${NC}"
    echo "================================"
    echo ""

    for scenario_file in "${SCENARIOS_DIR}"/*.md; do
        if [ -f "$scenario_file" ]; then
            name="$(basename "$scenario_file" .md)"
            # Extract the first heading as the title
            title="$(head -5 "$scenario_file" | grep '^# ' | head -1 | sed 's/^# //')"
            # Extract complexity from the file
            complexity="$(grep -m1 'Complexity:' "$scenario_file" | sed 's/.*Complexity: *//' || echo "unknown")"

            echo -e "  ${GREEN}${name}${NC}"
            echo "    Title:      ${title}"
            echo "    Complexity: ${complexity}"
            echo ""
        fi
    done

    echo "================================"
    echo ""
    echo "To see details of a scenario:"
    echo "  $(basename "$0") describe <scenario-name>"
    echo ""
    echo "To run a scenario, use Claude Code in a test project:"
    echo "  1. Create or navigate to a test project directory"
    echo "  2. Run: /dev-flow:init"
    echo "  3. Then issue the task described in the scenario"
    echo "  4. Verify each checkpoint listed in the scenario"
}

describe_scenario() {
    local name="$1"
    local file="${SCENARIOS_DIR}/${name}.md"

    if [ ! -f "$file" ]; then
        echo -e "${RED}Error: Scenario '${name}' not found.${NC}"
        echo ""
        echo "Available scenarios:"
        for f in "${SCENARIOS_DIR}"/*.md; do
            [ -f "$f" ] && echo "  - $(basename "$f" .md)"
        done
        exit 1
    fi

    echo -e "${BLUE}Scenario: ${name}${NC}"
    echo "================================"
    echo ""
    cat "$file"
}

# Main
case "${1:-help}" in
    list)
        list_scenarios
        ;;
    describe)
        if [ -z "${2:-}" ]; then
            echo -e "${RED}Error: Please specify a scenario name.${NC}"
            echo "Usage: $(basename "$0") describe <scenario-name>"
            exit 1
        fi
        describe_scenario "$2"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        usage
        exit 1
        ;;
esac
