#!/bin/bash
# ================================================================
# error-gate.sh — Unresolved Error Blocker
# ================================================================
# PURPOSE:
#   Detects unresolved errors in error log and blocks external
#   publishing actions until errors are cleared.
#
#   Allows local-only operations (read, edit, test, syntax check)
#   but blocks high-risk external actions that could propagate
#   errors to users (git push, npm publish, curl POST, etc).
#
# TRIGGER: PreToolUse
# MATCHER: "Bash"
#
# WHAT IT BLOCKS (exit 2) when errors exist:
#   - git push
#   - npm publish
#   - curl POST/PUT/DELETE
#   - Any external API calls
#
# WHAT IT ALLOWS (exit 0) even with errors:
#   - Local reads (cat, ls, grep, etc)
#   - Local edits and test runs
#   - Syntax checks
#   - All non-blocking operations
#
# CONFIGURATION:
#   CC_ERROR_LOG — path to error log file
#     default: "$HOME/.claude/error-tracker.log"
#
#   CC_ERROR_THRESHOLD — minimum severity to block external actions
#     default: "WARNING" (block on WARNING and ERROR)
#     Options: "ERROR", "WARNING", "INFO"
#
# NOTE: Error log format: each line = "TIMESTAMP|SEVERITY|MESSAGE"
# ================================================================

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# Get error log path from env
ERROR_LOG="${CC_ERROR_LOG:-$HOME/.claude/error-tracker.log}"
THRESHOLD="${CC_ERROR_THRESHOLD:-WARNING}"

# If no error log exists, allow everything
if [[ ! -f "$ERROR_LOG" ]]; then
    exit 0
fi

# Check if log has unresolved errors (non-empty and contains recent errors)
if [[ ! -s "$ERROR_LOG" ]]; then
    exit 0  # Empty file = no errors
fi

# Count errors matching threshold
ERROR_COUNT=0
if [[ "$THRESHOLD" == "ERROR" ]]; then
    ERROR_COUNT=$(grep -c "^[^|]*|ERROR|" "$ERROR_LOG" 2>/dev/null || echo 0)
else  # WARNING or INFO
    ERROR_COUNT=$(grep -cE "^[^|]*(|WARNING||ERROR|)" "$ERROR_LOG" 2>/dev/null || echo 0)
fi

if (( ERROR_COUNT == 0 )); then
    exit 0  # No matching errors
fi

# Check if this is an external action that should be blocked
BLOCKS_EXTERNAL=0

if echo "$COMMAND" | grep -qE '^\s*git\s+push'; then
    BLOCKS_EXTERNAL=1
elif echo "$COMMAND" | grep -qE '^\s*npm\s+publish'; then
    BLOCKS_EXTERNAL=1
elif echo "$COMMAND" | grep -qE 'curl\s+-(X(POST|PUT|DELETE)|d)'; then
    BLOCKS_EXTERNAL=1
elif echo "$COMMAND" | grep -qE 'curl\s+.*(-d|-X(POST|PUT|DELETE))'; then
    BLOCKS_EXTERNAL=1
fi

# If not an external action, allow it
if (( BLOCKS_EXTERNAL == 0 )); then
    exit 0
fi

# Block external action due to unresolved errors
echo "BLOCKED: Unresolved errors in error log." >&2
echo "" >&2
echo "Error log: $ERROR_LOG" >&2
echo "Unresolved errors: $ERROR_COUNT" >&2
echo "" >&2
echo "External actions are blocked until errors are resolved." >&2
echo "Review the error log and fix issues before publishing." >&2
exit 2
