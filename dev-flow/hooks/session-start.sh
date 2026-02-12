#!/usr/bin/env bash
# =============================================================================
# dev-flow session-start hook
# =============================================================================
# Runs on every session start (async). Performs a quick validation of the
# pipeline configuration if it exists. Designed to be fast and silent --
# never nags the user to run /dev-flow:init.
# =============================================================================

set -euo pipefail

CONFIG_FILE=".claude/dev-flow/config.yaml"

# Exit silently if no config exists -- user has not run /dev-flow:init yet
if [ ! -f "$CONFIG_FILE" ]; then
  exit 0
fi

# Validate that the config has a version field (basic sanity check)
if ! grep -q '^version:' "$CONFIG_FILE" 2>/dev/null; then
  echo "[dev-flow] Warning: $CONFIG_FILE is missing the 'version' field. Run /dev-flow:init to regenerate." >&2
fi

exit 0
