#!/usr/bin/env bash
# =============================================================================
# dev-flow approval-gate hook (PreToolUse)
# =============================================================================
# Blocks Edit/Write/Bash calls that touch paths or commands the project has
# marked as requiring human approval, via .claude/dev-flow/approval-gates.yaml.
# Silent no-op if that file doesn't exist -- this gate is opt-in per project.
#
# Exit 0  -> allow the tool call
# Exit 2  -> block the tool call; stderr is shown to the agent as the reason
# =============================================================================

set -euo pipefail

GATES_FILE=".claude/dev-flow/approval-gates.yaml"

# Opt-in: no gates file, no enforcement.
[ -f "$GATES_FILE" ] || exit 0

INPUT="$(cat)"

# Extract tool_name and the relevant argument (file_path for Edit/Write, command for Bash).
# Prefer jq, fall back to python3, fail open (allow + warn) if neither is available --
# a missing JSON parser should not hard-block every tool call in the session.
# ponytail: flat-file parser below, upgrade to a real YAML lib if gates.yaml grows nested structure.
if command -v jq >/dev/null 2>&1; then
  TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"
  TARGET="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.command // empty')"
elif command -v python3 >/dev/null 2>&1; then
  TOOL_NAME="$(echo "$INPUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("tool_name",""))' 2>/dev/null || true)"
  TARGET="$(echo "$INPUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); ti=d.get("tool_input",{}); print(ti.get("file_path") or ti.get("command") or "")' 2>/dev/null || true)"
else
  echo "[dev-flow] approval-gate: no jq or python3 available, cannot enforce gates this call." >&2
  exit 0
fi

[ -n "${TOOL_NAME:-}" ] || exit 0
[ -n "${TARGET:-}" ] || exit 0

# Only gate the tools that actually mutate state or run commands.
case "$TOOL_NAME" in
  Edit|Write|Bash) ;;
  *) exit 0 ;;
esac

# --- protected_paths: block Edit/Write to matching paths -------------------
if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
  while IFS= read -r pattern; do
    [ -n "$pattern" ] || continue
    case "$TARGET" in
      *"$pattern"*)
        echo "[dev-flow] Blocked: '$TARGET' matches protected path '$pattern' in $GATES_FILE. This path requires human approval -- ask the user to make this change or explicitly approve it." >&2
        exit 2
        ;;
    esac
  done < <(sed -n '/^protected_paths:/,/^[a-zA-Z_-]*:/{/^ *- /p}' "$GATES_FILE" | sed "s/^ *- //; s/^[\"']//; s/[\"']\$//")
fi

# --- blocked_commands: block Bash calls containing a listed substring ------
if [ "$TOOL_NAME" = "Bash" ]; then
  while IFS= read -r pattern; do
    [ -n "$pattern" ] || continue
    case "$TARGET" in
      *"$pattern"*)
        echo "[dev-flow] Blocked: command matches blocked pattern '$pattern' in $GATES_FILE. This action requires human/release approval -- do not attempt to bypass this gate." >&2
        exit 2
        ;;
    esac
  done < <(sed -n '/^blocked_commands:/,/^[a-zA-Z_-]*:/{/^ *- /p}' "$GATES_FILE" | sed "s/^ *- //; s/^[\"']//; s/[\"']\$//")
fi

exit 0
