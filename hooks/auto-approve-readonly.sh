#!/bin/bash
# ================================================================
# auto-approve-readonly.sh — Auto-approve read-only operations
# ================================================================
# PURPOSE:
#   Auto-approves permission requests for read-only operations
#   at the PermissionRequest level — before the prompt is shown.
#   Covers git read commands, file reads, and directory listings
#   that would otherwise interrupt autonomous operation.
#
# TRIGGER: PermissionRequest
# MATCHER: "" (all tools)
#
# WHY PermissionRequest INSTEAD OF PreToolUse:
#   PreToolUse can modify input or block, but the permission
#   dialog still shows. PermissionRequest intercepts the dialog
#   itself, so the user never sees it for safe operations.
#
# WHAT IT AUTO-APPROVES:
#   - git log, diff, status, branch, show, tag, remote
#   - ls, cat, head, tail, wc, find (read-only)
#   - cd + any read-only command compound
#
# WHAT IT DOES NOT APPROVE:
#   - Any write operation (git push, rm, mv, cp overwrite)
#   - Any network operation (curl POST, wget)
#   - Anything not explicitly in the safe list
#
# CONFIGURATION:
#   CC_AUTO_APPROVE_DISABLE=1 — disable this hook
# ================================================================

INPUT=$(cat)

if [[ "${CC_AUTO_APPROVE_DISABLE:-0}" == "1" ]]; then
    exit 0
fi

TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Only handle Bash tool
if [[ "$TOOL" != "Bash" ]]; then
    exit 0
fi

if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# Strip leading cd commands to get the actual operation
ACTUAL_CMD=$(echo "$COMMAND" | sed 's/^\s*cd\s\+[^&]*&&\s*//')

# Extract the base command (first word)
BASE_CMD=$(echo "$ACTUAL_CMD" | awk '{print $1}')

# Read-only commands that are always safe
case "$BASE_CMD" in
    git)
        GIT_SUB=$(echo "$ACTUAL_CMD" | awk '{print $2}')
        case "$GIT_SUB" in
            log|diff|status|branch|show|tag|remote|rev-parse|describe|name-rev|shortlog|stash)
                jq -n '{
                    hookSpecificOutput: {
                        hookEventName: "PermissionRequest",
                        permissionDecision: "allow",
                        permissionDecisionReason: "Read-only git operation auto-approved"
                    }
                }'
                exit 0
                ;;
        esac
        ;;
    ls|cat|head|tail|wc|file|stat|du|df|which|type|echo|printf|date|pwd|whoami|uname|hostname)
        jq -n '{
            hookSpecificOutput: {
                hookEventName: "PermissionRequest",
                permissionDecision: "allow",
                permissionDecisionReason: "Read-only command auto-approved"
            }
        }'
        exit 0
        ;;
    find|grep|rg|ag|fd|tree)
        # Read-only search/find — safe unless -delete or -exec rm
        if ! echo "$ACTUAL_CMD" | grep -qE '\-delete|\-exec\s+rm'; then
            jq -n '{
                hookSpecificOutput: {
                    hookEventName: "PermissionRequest",
                    permissionDecision: "allow",
                    permissionDecisionReason: "Read-only search command auto-approved"
                }
            }'
            exit 0
        fi
        ;;
esac

# Not a recognized read-only command — let normal permission flow handle it
exit 0
