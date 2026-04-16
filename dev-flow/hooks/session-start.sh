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

# Ensure config directory exists (tracked in git).
mkdir -p .claude/dev-flow

# Ensure .dev-flow/ is in the project's .gitignore (runtime artifacts, not tracked).
if [ -f .gitignore ]; then
  grep -qxF '.dev-flow/' .gitignore || echo '.dev-flow/' >> .gitignore
else
  echo '.dev-flow/' > .gitignore
fi

# Clean up stale session directories older than 24 hours (safety net for crash/abort).
if [ -d .dev-flow ]; then
  find .dev-flow -maxdepth 1 -mindepth 1 -type d -mmin +1440 -exec rm -rf {} + 2>/dev/null || true
fi

# Clean up stale watchdog files from previous sessions.
rm -f .claude/dev-flow/.watchdog-* 2>/dev/null || true

exit 0
